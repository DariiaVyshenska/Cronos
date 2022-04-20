require "pg"

class DatabasePersistance
  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "todos")
          end
    @logger = logger
  end

  def disconnect
    @db.close
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(list_id)
    sql = "SELECT * FROM lists WHERE id = $1"
    result = query(sql, list_id)

    tuple = result.first
    {id: tuple["id"].to_i, name: tuple["name"], todos: list_todos(list_id)}
  end

  def all_lists
    sql =  "SELECT * FROM lists"
    result = query(sql)

    result.map do |tuple|
      {id: tuple["id"].to_i, name: tuple["name"], todos: list_todos(tuple["id"].to_i)}
    end
  end

  def create_new_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1)"
    query(sql, list_name)
  end

  def delete_list(list_id)
    sql_todos = "DELETE FROM todos WHERE list_id = $1"
    query(sql_todos, list_id)
    sql_lists = "DELETE FROM lists WHERE id = $1"
    query(sql_lists, list_id)
  end

  def update_list_name(list_id, list_new_name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2"
    query(sql, list_new_name, list_id)
  end

  def create_new_todo(list_id, new_todo)
      sql = "INSERT INTO todos (list_id, name) VALUES ($1, $2)"
      query(sql, list_id, new_todo)
  end

  def delete_todo_from_list(list_id, todo_id)
    sql = "DELETE FROM todos WHERE list_id = $1 AND id = $2"
    query(sql, list_id, todo_id)
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = "UPDATE todos SET completed = $1 WHERE list_id = $2 AND id = $3"
    query(sql, new_status, list_id, todo_id)
  end

  def mark_all_todos_as_completed(list_id)
    sql = "UPDATE todos SET completed = true WHERE list_id = $1"
    query(sql, list_id)
  end

  private

  def list_todos(list_id)
    sql = "SELECT id, name, completed FROM todos WHERE list_id = $1"
    result = query(sql, list_id)

    result.map do |tuple|
      { id: tuple["id"].to_i, name: tuple["name"], completed: str_to_bool(tuple["completed"]) }
    end
  end

  def str_to_bool(str)
    ['t', 'true'].include?(str.downcase)
  end
end
