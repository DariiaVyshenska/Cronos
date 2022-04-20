require 'sinatra'
require 'tilt/erubis'
require 'sinatra/content_for'

require_relative "database_persistence.rb"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload "database_persistence.rb"
end

before do
  @storage = DatabasePersistance.new(logger)
end

helpers do
  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| all_done?(list) }

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end

  def todos_count(list)
    list[:todos].size
  end

  def todos_count_done(list)
    list[:todos].select { |todo| todo[:completed] }.size
  end

  def todos_count_not_done(list)
    todos_count(list) - todos_count_done(list)
  end

  def all_done?(list)
    todos_count_not_done(list).zero? && !todos_count(list).zero?
  end

  def list_class(list)
    'complete' if all_done?(list)
  end
end

def load_list(list_id)
  list = @storage.find_list(list_id)
  return list if list

  session[:error] = 'The specified list was not found.'
  redirect '/lists'
end

get '/' do
  redirect '/lists'
end

# View list of lists
get '/lists' do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Return an error message if the name is invalid. Return nil if the name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'List name must be between 1 and 100 characters.'
  elsif @storage.all_lists.any? { |list| list[:name] == name }
    'List name must be unique.'
  end
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip
  if (error = error_for_list_name(list_name))
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_new_list(list_name)
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Render a to-do list for a particular list
get '/lists/:id' do
  @list_id = params[:id].to_i

  @list = load_list(@list_id)
  @list_todos = @list[:todos]
  erb :list, layout: :layout
end

# Edit an existing todo list
get '/lists/:id/edit' do
  list_id = params[:id].to_i
  @list = load_list(list_id)
  erb :edit_list, layout: :layout
end

# Update an existing todo list
post '/lists/:id' do
  list_new_name = params[:list_new_name].strip if params[:list_new_name]
  list_id = params[:id].to_i
  @list = load_list(list_id)

  if (error = error_for_list_name(list_new_name))
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    list_new_name = params[:list_new_name].strip
    @storage.update_list_name(list_id, list_new_name)
    session[:success] = 'The list has been modified.'
    redirect "/lists/#{list_id}"
  end
end

# Delete a todo list
post '/lists/:id/destroy' do
  list_id = params[:id].to_i
  @storage.delete_list(list_id)

  session[:success] = 'The list has been deleted.'
  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    '/lists'
  else
    redirect '/lists'
  end
end

# Add a todo item to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @list_todos = @list[:todos]
  new_todo = params[:todo].strip

  if (error = error_for_todo(new_todo))
    session[:error] = error
    erb :list, layout: :layout
  else
    @storage.create_new_todo(@list_id, new_todo)

    session[:success] = 'The todo was added.'
    redirect "lists/#{@list_id}"
  end
end

def error_for_todo(name)
  'Todo must be between 1 and 100 characters.' unless (1..100).cover? name.size
end

# Delete an item from the list
post '/lists/:list_id/todos/:todo_id/destroy' do
  @list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i

  @storage.delete_todo_from_list(@list_id, todo_id)
  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    status 204
  else
    session[:success] = 'The todo has been deleted.'
    redirect "/lists/#{@list_id}"
  end
end


# Update the status of a todo
post '/lists/:list_id/todos/:todo_id' do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  new_val = (params[:completed].to_s.downcase == 'true')

  @storage.update_todo_status(list_id, todo_id, new_val)

  session[:success] = 'The todo has been updated.'
  redirect "lists/#{list_id}"
end

post '/lists/:list_id/complete_all' do
  list_id = params[:list_id].to_i
  @storage.mark_all_todos_as_completed(list_id)

  session[:success] = 'All todos have been completed.'
  redirect "lists/#{list_id}"
end
