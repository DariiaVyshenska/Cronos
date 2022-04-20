require "pg"

class SessionPersistance
  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def find_list(list_id)
    @session[:lists].find { |el| el[:id] == list_id }
  end

  def all_lists
    @session[:lists]
  end

  def create_new_list(list_name)
    list_id = next_element_id(all_lists)
    all_lists << { id: list_id, name: list_name, todos: [] }
  end

  def delete_list(list_id)
    all_lists.reject! { |list| list[:id] == list_id }
  end

  def update_list_name(list_id, list_new_name)
    list = find_list(list_id)
    list[:name] = list_new_name
  end

  def create_new_todo(list_id, new_todo)
    list = find_list(list_id)
    id = next_element_id(list[:todos])
    list[:todos] << { id: id, name: new_todo, completed: false }
  end

  def delete_todo_from_list(list_id, todo_id)
    list = find_list(list_id)
    list[:todos].reject! { |todo| todo[:id] == todo_id }
  end

  def update_todo_status(list_id, todo_id, new_status)
    list = find_list(list_id)
    todo = list[:todos].find { |el| el[:id] == todo_id }
    todo[:completed] = new_status
  end

  def mark_all_todos_as_completed(list_id)
    list = find_list(list_id)
    list[:todos].each { |todo| todo[:completed] = true }
  end

  private

  def next_element_id(elements)
    max = elements.map { |element| element[:id] }.max || 0
    max + 1
  end
end
