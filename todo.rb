require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'sinatra/content_for'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

helpers do
  def sort_lists(list, &block)
    order_items(list, block) { |item| !all_done?(item) }
  end

  def sort_todos(todos, &block)
    order_items(todos, block) { |item| !item[:completed] }
  end

  def order_items(list, block)
    list_with_idx = list.map.with_index { |item, idx| [item, idx] }
    sorted_list_with_idx = list_with_idx.partition do |(item, _)|
      yield(item)
    end.flatten(1)
    sorted_list_with_idx.each { |(item, idx)| block.call(item, idx) }
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
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Render a to-do list for a particular list
get '/lists/:id' do
  @list_id = params[:id].to_i
  return 'NO SUCH LIST' unless (0...session[:lists].size).cover?(@list_id)

  @list = session[:lists][@list_id]
  @list_todos = session[:lists][@list_id][:todos]
  erb :list, layout: :layout
end

# Edit an existing todo list
get '/lists/:id/edit' do
  list_id = params[:id].to_i
  @list = session[:lists][list_id]
  erb :edit_list, layout: :layout
end

# Update an existing todo list
post '/lists/:id' do
  list_new_name = params[:list_new_name].strip if params[:list_new_name]
  list_id = params[:id].to_i
  @list = session[:lists][list_id]

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
  session[:lists].delete_at(params[:id].to_i)
  session[:success] = 'The list has been deleted.'
  redirect '/lists'
end

# Add a todo item to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  @list_todos = @list[:todos]
  new_todo = params[:todo].strip

  if (error = error_for_todo(new_todo))
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: new_todo, completed: false }
    session[:success] = 'The todo was added.'
    redirect "lists/#{@list_id}"
  end
end

def error_for_todo(name)
  'Todo must be between 1 and 100 characters.' unless (1..100).cover? name.size
end

# Delete an item from the list
post '/lists/:list_id/todos/:todo_id/destroy' do     # DONE!
  list_id = params[:list_id].to_i
  list = session[:lists][list_id]

  todo_id = params[:todo_id].to_i
  list[:todos].delete_at(todo_id)
  session[:success] = 'The todo has been deleted.'
  redirect "/lists/#{list_id}"
end

post '/lists/:list_id/todos/:todo_id' do
  list_id = params[:list_id].to_i
  list = session[:lists][list_id]

  todo_id = params[:todo_id].to_i
  new_val = (params[:completed].to_s.downcase == 'true')
  list[:todos][todo_id][:completed] = new_val

  session[:success] = 'The todo has been updated.'
  redirect "lists/#{list_id}"
end

post '/lists/:list_id/complete_all' do
  list_id = params[:list_id].to_i
  list = session[:lists][list_id]
  list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = 'All todos have been completed.'
  redirect "lists/#{list_id}"
end
