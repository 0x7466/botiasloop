# SQLite Specifics

SQLite-specific features, types, and limitations when using Sequel.

## Connection Types

### In-Memory Database

```ruby
# Temporary, data lost when connection closes
DB = Sequel.sqlite

# Shared cache (multiple connections to same memory DB)
DB = Sequel.sqlite("file::memory:?cache=shared")
```

### File-Based Database

```ruby
# Relative path
DB = Sequel.sqlite("data.db")

# Absolute path
DB = Sequel.sqlite("/var/lib/app/data.db")

# Read-only
DB = Sequel.sqlite("data.db", mode: "ro")

# Create if not exists (default)
DB = Sequel.sqlite("data.db", mode: "rwc")
```

### Connection Options

```ruby
DB = Sequel.sqlite("data.db",
  timeout: 5000,           # Busy timeout in ms
  synchronous: :normal,    # OFF, NORMAL, FULL
  journal_mode: :wal,      # DELETE, TRUNCATE, PERSIST, MEMORY, WAL, OFF
  foreign_keys: true,      # Enforce foreign key constraints
  case_sensitive_like: false,
  encoding: "UTF-8"
)
```

## Data Types

SQLite uses dynamic typing (affinity), but Sequel maps Ruby types:

| Sequel Type | SQLite Storage | Ruby Class |
|-------------|----------------|------------|
| `String` | TEXT | String |
| `Integer` | INTEGER | Integer |
| `Float` / `BigDecimal` | REAL | Float / BigDecimal |
| `Date` | TEXT | Date |
| `DateTime` | TEXT | Time |
| `Time` | TEXT | Time |
| `TrueClass` / `FalseClass` | INTEGER (0/1) | TrueClass / FalseClass |
| `BLOB` | BLOB | String |

### Type Examples

```ruby
DB.create_table :items do
  primary_key :id
  
  String :name, null: false
  String :description, text: true  # TEXT affinity
  Integer :quantity
  Float :price
  Date :available_on
  DateTime :created_at
  Time :expires_at
  TrueClass :in_stock, default: true
  BLOB :image_data
end
```

### Boolean Handling

```ruby
# SQLite stores booleans as 0/1
item = Item.create(in_stock: true)
item.in_stock  # => true (Sequel converts automatically)

# In raw SQL
DB[:items].where(in_stock: true)
# Generates: WHERE (in_stock = 1)
```

### Date/Time Handling

```ruby
# Stored as ISO8601 strings
DB.create_table :events do
  DateTime :starts_at
end

# Sequel handles conversion
Event.create(starts_at: Time.now)
Event.where { starts_at > Date.today }
```

## SQLite Pragmas

### Setting Pragmas

```ruby
# After connection
DB.execute("PRAGMA journal_mode = WAL")
DB.execute("PRAGMA synchronous = NORMAL")
DB.execute("PRAGMA foreign_keys = ON")
DB.execute("PRAGMA busy_timeout = 5000")

# Or during connection
DB = Sequel.sqlite("data.db", journal_mode: :wal)
```

### Important Pragmas

```ruby
# WAL mode for better concurrency
DB.execute("PRAGMA journal_mode = WAL")

# Foreign key enforcement (off by default!)
DB.execute("PRAGMA foreign_keys = ON")

# Case-insensitive LIKE
DB.execute("PRAGMA case_sensitive_like = OFF")

# Secure delete (overwrite deleted data with zeros)
DB.execute("PRAGMA secure_delete = ON")
```

## Limitations

### Single Writer

SQLite allows multiple readers but only one writer at a time:

```ruby
# Concurrent writes will get "database is locked" errors
# Use busy_timeout to wait instead of failing
DB = Sequel.sqlite("data.db", timeout: 5000)
```

### No ALTER COLUMN

SQLite doesn't support modifying column types directly:

```ruby
# Sequel handles this via table recreation
# In migrations, this is automatic
change do
  set_column_type :posts, :body, :text
end
```

### Limited ALTER TABLE

SQLite supports:
- RENAME TABLE
- ADD COLUMN
- RENAME COLUMN (SQLite 3.25.0+)

```ruby
# These work
add_column :posts, :summary, String
rename_column :posts, :summary, :excerpt

# These require table recreation
set_column_type :posts, :body, :text
set_column_default :posts, :views, 0
set_column_null :posts, :title, false
```

### No RIGHT/FULL JOIN

SQLite only supports INNER, LEFT, and CROSS joins:

```ruby
# Works
DB[:posts].join(:authors, id: :author_id)       # INNER
DB[:posts].left_join(:authors, id: :author_id)   # LEFT

# Not supported (Sequel will raise error)
DB[:posts].right_join(:authors, id: :author_id)
DB[:posts].full_join(:authors, id: :author_id)
```

### No CONCURRENT Index Creation

```ruby
# SQLite doesn't support CONCURRENT keyword
# Sequel will ignore it
add_index :posts, :title, concurrently: true  # Works, but not concurrent
```

### Row ID

SQLite uses implicit `rowid` unless `WITHOUT ROWID`:

```ruby
# With rowid (default)
create_table :items do
  Integer :id, primary_key: true  # Actually aliases rowid
end

# Without rowid (clustered primary key)
create_table :items, without_rowid: true do
  Integer :id, primary_key: true  # Real column
end
```

## Features

### Auto-Increment

```ruby
# Integer primary key auto-increments
create_table :posts do
  primary_key :id  # INTEGER PRIMARY KEY AUTOINCREMENT
end

# Explicit auto-increment
create_table :posts do
  Integer :id, primary_key: true, auto_increment: true
end
```

### FTS (Full-Text Search)

```ruby
# Requires fts5 extension
DB.execute(<<-SQL)
  CREATE VIRTUAL TABLE posts_fts USING fts5(
    title, body,
    content='posts',
    content_rowid='id'
  )
SQL

# Query
DB.execute("SELECT * FROM posts_fts WHERE posts_fts MATCH 'sequel'")
```

### JSON Support

```ruby
# SQLite 3.38.0+ has built-in JSON
create_table :posts do
  String :metadata, default: "{}"
end

# Query JSON
DB["SELECT * FROM posts WHERE json_extract(metadata, '$.published') = 1"]
```

### R-Tree Extension

```ruby
# Spatial indexing
DB.execute(<<-SQL)
  CREATE VIRTUAL TABLE places USING rtree(
    id,
    min_lat, max_lat,
    min_lon, max_lon
  )
SQL
```

## Connection Pooling

SQLite with file-backed databases works best with single connection:

```ruby
# Single connection (recommended for SQLite)
DB = Sequel.sqlite("data.db", max_connections: 1)

# Or use single connection mode
DB = Sequel.connect("sqlite://data.db?max_connections=1")
```

For in-memory with multiple threads:

```ruby
# Shared cache mode
DB = Sequel.sqlite("file::memory:?cache=shared", pool_timeout: 30)
```

## Backup

```ruby
# Backup to another database
backup_db = Sequel.sqlite("backup.db")
DB.tables.each do |table|
  DB[table].each do |row|
    backup_db[table].insert(row)
  end
end
```

## Best Practices

1. **Enable foreign keys**: `PRAGMA foreign_keys = ON`
2. **Use WAL mode**: `PRAGMA journal_mode = WAL`
3. **Set busy timeout**: `timeout: 5000`
4. **Single connection**: `max_connections: 1`
5. **Index frequently queried columns**
6. **Vacuum periodically**: `DB.execute("VACUUM")`
7. **Analyze for query optimization**: `DB.execute("ANALYZE")`

## Migrations with SQLite

SQLite's limited ALTER TABLE means migrations sometimes recreate tables:

```ruby
Sequel.migration do
  up do
    # Adding column - simple
    add_column :posts, :summary, String
    
    # Changing column type - requires table recreation
    set_column_type :posts, :body, :text
    # Sequel automatically handles this
  end
end
```
