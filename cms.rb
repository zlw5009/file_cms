require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

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

def signed_in?
  session.key?(:username)
end

def signin_required
  unless signed_in?
    session[:message] = "You must sign in first." 
    redirect "/"
  end
end

def load_user_credentials
  user_credentials = if ENV["RACK_ENV"] == "test"
                       File.expand_path("../test/users.yml", __FILE__)
                     else
                       File.expand_path("../users.yml", __FILE__)
                     end
  YAML.load_file(user_credentials)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

# Sign-In
get "/users/signin" do
  erb :signin, layout: :layout
end

post "/users/signin" do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid credentials"
    status 422
    erb :signin
  end
end

# Sign-out
post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
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
  signin_required
  erb :new
end

post "/create" do
  signin_required

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
  signin_required

  file_path = File.join(data_path, params[:file])

  @file_name = params[:file]
  @file_content = File.read(file_path)

  erb :edit, layout: :layout
end

# Update contents of file
post "/:file" do
  signin_required

  file_path = File.join(data_path, params[:file])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:file]} has been updated successfully."
  redirect "/"
end

# Delete file
post "/:file/delete" do
  signin_required

  file_path = File.join(data_path, params[:file])

  File.delete(file_path)
  session[:message] = "#{params[:file]} has been deleted successfully."
  redirect "/"
end
