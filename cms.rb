require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def render_markdown(file_text)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(file_text)
end

def load_file(path)
  content = File.read(path)
  case File.extname(path)
  when ".md"
    erb render_markdown(content)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  end
end

# Homepage: Index of all stored files
get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index, layout: :layout
end

# Add a new file
get "/new" do
  erb :new
end

post "/create" do
  file_name = params[:file_name].to_s

  if File.extname(file_name) == ""
    session[:message] = "A file name with an extension is required."
    status 422
    erb :new
  else
    file_path = File.join(data_path, file_name)

    File.write(file_path, "")
    session[:message] = "#{params[:file_name]} has been created successfully."

    redirect "/"
  end
end

# Displays contents of :file
get "/:file" do
  file_path = File.join(data_path, params[:file])

  if File.file?(file_path)
    load_file(file_path)
  else
    session[:message] = "#{params[:file]} does not exist."
    redirect "/"
  end
end

# View content to make edits
get "/:file/edit" do
  file_path = File.join(data_path, params[:file])

  @file_name = params[:file]
  @file_content = File.read(file_path)

  erb :edit, layout: :layout
end

# Update contents of file
post "/:file" do
  file_path = File.join(data_path, params[:file])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:file]} has been updated successfully."
  redirect "/"
end

# Delete file
post "/:file/delete" do
  file_path = File.join(data_path, params[:file])

  File.delete(file_path)
  session[:message] = "#{params[:file]} has been deleted successfully."
  redirect "/"
end
