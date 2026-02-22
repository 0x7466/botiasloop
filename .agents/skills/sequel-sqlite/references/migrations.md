# Migrations

Sequel migrations provide versioned database schema changes.

## Migration Structure

Migrations are Ruby files in `db/migrations/` named with numeric prefixes:
- `001_create_posts.rb`
- `002_add_users.rb`
- `003_create_comments.rb`

## Migration Types

### Change Migrations (Recommended)

Use `change` for reversible operations:

```ruby
Sequel.migration do
  change do
    create_table :posts do
      primary_key :id
      String :title, null: false
      String :body, text: true
      DateTime :created_at
    end
  end
end
```

Reversible operations: `create_table`, `add_column`, `add_index`, etc.

### Up/Down Migrations

Use explicit `up` and `down` for complex changes:

```ruby
Sequel.migration do
  up do
    add_column :posts, :published, TrueClass, default: false
  end
  
  down do
    drop_column :posts, :published
  end
end
```

## Schema Modification Methods

### Tables

```ruby
create_table :posts do
  primary_key :id
  String :title, null: false
  Integer :views, default: 0
  DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
  foreign_key :author_id, :authors
  
  index :title, unique: true
  index [:author_id, :created_at]
end

drop_table :posts
drop_table? :posts  # No error if doesn't exist
```

### Columns

```ruby
add_column :posts, :summary, String
add_column :posts, :priority, Integer, default: 1

drop_column :posts, :summary
rename_column :posts, :summary, :excerpt
set_column_default :posts, :views, 0
set_column_type :posts, :body, :text
```

### Indexes

```ruby
add_index :posts, :title
add_index :posts, [:author_id, :created_at], unique: true
drop_index :posts, :title
```

## Running Migrations

### Programmatic

```ruby
require "sequel"

DB = Sequel.sqlite("app.db")

# Run all pending migrations
Sequel::Migrator.run(DB, "db/migrations")

# Migrate to specific version
Sequel::Migrator.run(DB, "db/migrations", target: 5)

# Rollback to previous version
Sequel::Migrator.run(DB, "db/migrations", target: 0) # Back to start
```

### Migration Check

```ruby
# Check current schema version
DB[:schema_info].get(:version) rescue nil
```

## Column Types

SQLite supports these Sequel types:

- `String` → VARCHAR/TEXT
- `Integer` → INTEGER
- `Float` → REAL
- `DateTime` → TEXT (ISO8601 format)
- `Date` → TEXT
- `Time` → TEXT
- `TrueClass`/`FalseClass` → INTEGER (0/1)
- `BLOB` → BLOB
- `BigDecimal` → REAL

## Migration Best Practices

1. **Always use numeric prefixes** - Timestamp prefixes are not recommended for Sequel
2. **Keep migrations reversible** - Prefer `change` over `up`/`down`
3. **Don't modify existing migrations** - Create new migrations to alter schema
4. **Set defaults** - Use `default:` option for required columns
5. **Add indexes early** - Performance is harder to fix later
6. **Test migrations** - Run them against a fresh database before deploying

## Irreversible Migrations

For operations that can't be reversed (data transformations):

```ruby
Sequel.migration do
  up do
    DB[:posts].update(published: true) where(published: nil)
  end
  
  down do
    raise Sequel::Error, "Cannot reverse data migration"
  end
end
```
