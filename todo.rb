require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'sinatra/content_for'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

before do
  session[:lists] ||= []
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

def next_element_id(elements)
  max = elements.map { |element| element[:id] }.max || 0
  max + 1
end

def load_list(list_id)
  list = session[:lists].find { |el| el[:id] == list_id }
  return list if list

  session[:error] = 'The specified list was not found.'
  redirect '/lists'
end

get '/' do
  redirect '/lists'
end

# View list of lists
get '/lists' do
  @lists = session[:lists]
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
  elsif session[:lists].any? { |list| list[:name] == name }
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
    list_id = next_element_id(session[:lists])
    session[:lists] << { id: list_id, name: list_name, todos: [] }
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
    @list[:name] = params[:list_new_name].strip
    session[:success] = 'The list has been modified.'
    redirect "/lists/#{list_id}"
  end
end

# Delete a todo list
post '/lists/:id/destroy' do
  list_id = params[:id].to_i
  session[:lists].reject! { |list| list[:id] == list_id }

  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    '/lists'
  else
    session[:success] = 'The list has been deleted.'
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
    id = next_element_id(@list[:todos])
    @list[:todos] << { id: id, name: new_todo, completed: false }

    session[:success] = 'The todo was added.'
    redirect "lists/#{@list_id}"
  end
end

def error_for_todo(name)
  'Todo must be between 1 and 100 characters.' unless (1..100).cover? name.size
end

# Delete an item from the list
post '/lists/:list_id/todos/:todo_id/destroy' do
  list_id = params[:list_id].to_i
  list = load_list(list_id)

  todo_id = params[:todo_id].to_i
  list[:todos].reject! { |todo| todo[:id] == todo_id }

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
  list = load_list(list_id)

  todo_id = params[:todo_id].to_i
  new_val = (params[:completed].to_s.downcase == 'true')
  todo = list[:todos].find { |el| el[:id] == todo_id }
  todo[:completed] = new_val

  session[:success] = 'The todo has been updated.'
  redirect "lists/#{list_id}"
end

post '/lists/:list_id/complete_all' do
  list_id = params[:list_id].to_i
  list = load_list(list_id)
  list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = 'All todos have been completed.'
  redirect "lists/#{list_id}"
end
