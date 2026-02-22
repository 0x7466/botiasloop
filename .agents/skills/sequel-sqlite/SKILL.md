---
name: sequel-sqlite
description: Work with SQLite databases using Sequel's Model ORM. Use for local persistence, data modeling, and migrations.
metadata:
  author: botiasloop
  version: "1.0"
---

# Sequel SQLite Skill

## Quick Start

```ruby
require "sequel"

# Connect to SQLite (memory or file)
DB = Sequel.sqlite # In-memory
DB = Sequel.sqlite("data.db") # File-based

# Define a model
class Post < Sequel::Model
  many_to_one :author
  one_to_many :comments
end

# CRUD operations
post = Post.create(title: "Hello", body: "World")
Post[1] # Find by primary key
Post.where(title: "Hello").first
post.update(body: "Updated")
post.destroy
```

## Project Structure

```
project/
├── config.rb              # DB connection
├── models/
│   ├── post.rb
│   └── author.rb
├── db/
│   └── migrations/        # Migration files
│       ├── 001_create_posts.rb
│       └── 002_create_authors.rb
└── seeds.rb               # Optional seed data
```

## Core Concepts

**Datasets**: Immutable query objects. Chain methods like `where`, `order`, `limit` to build queries. Call `all`, `first`, `each` to execute.

**Models**: Classes inheriting from `Sequel::Model`. Provide ORM layer with associations, validations, and hooks. Table names are underscored plurals (`Post` → `posts`).

**Migrations**: Versioned schema changes stored in `db/migrations/`. Files named `XXX_description.rb`. Use `Sequel::Migrator` to apply.

## Common Patterns

### CRUD

```ruby
# Create
post = Post.new(title: "Hello")
post.save
# or
post = Post.create(title: "Hello")

# Read
Post[1]                    # By primary key
Post.first(title: "Hello") # With filter
Post.where(draft: true).order(:created_at).limit(10).all

# Update
post.update(title: "Updated")

# Delete
post.delete     # Bypasses hooks
post.destroy    # Runs hooks
```

### Associations

```ruby
class Author < Sequel::Model
  one_to_many :posts
end

class Post < Sequel::Model
  many_to_one :author
  many_to_many :tags
end

# Usage
author = Author.create(name: "John")
author.add_post(title: "First")
author.posts # Dataset of all posts
```

### Transactions

```ruby
DB.transaction do
  Post.create(title: "A")
  Post.create(title: "B")
  raise Sequel::Rollback # Rollback without error
end
```

### Virtual Row Blocks

```ruby
# Use blocks for complex filters
Post.where{ created_at > Date.today - 7 }
Post.where{ (views > 100) & (draft == false) }
```

### Schema Changes

```ruby
# In migration file (db/migrations/001_create_posts.rb)
Sequel.migration do
  change do
    create_table :posts do
      primary_key :id
      String :title, null: false
      String :body, text: true
      Integer :views, default: 0
      foreign_key :author_id, :authors
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end

# Run migrations
Sequel::Migrator.run(DB, "db/migrations")
```

## References

- [Migrations](references/migrations.md) - Creating and running migrations
- [Models](references/models.md) - Model definition and CRUD
- [Querying](references/querying.md) - Filters, ordering, aggregations
- [Associations](references/associations.md) - Model relationships
- [Validations & Hooks](references/validations-hooks.md) - Data integrity
- [Testing](references/testing.md) - Test patterns for Sequel
- [SQLite Specifics](references/sqlite-specific.md) - Types and limitations
