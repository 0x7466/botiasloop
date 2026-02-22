# Models

Models wrap database tables and provide ORM functionality.

## Model Definition

```ruby
class Post < Sequel::Model
  # Table name automatically inferred as :posts
end

# Explicit table name
class Article < Sequel::Model(:posts)
end
```

## Primary Keys

```ruby
class Post < Sequel::Model
  # Auto-detected single-column primary key (e.g., :id)
end

# Composite primary key
class Tagging < Sequel::Model
  set_primary_key [:tag_id, :post_id]
end

# No primary key
class Log < Sequel::Model
  no_primary_key
end
```

## CRUD Operations

### Create

```ruby
# Method 1: New then save
post = Post.new(title: "Hello")
post.body = "Content"
post.save  # Returns self or raises error

# Method 2: Create (new + save in one)
post = Post.create(title: "Hello", body: "Content")

# Method 3: Create with block
post = Post.create do |p|
  p.title = "Hello"
  p.body = "Content"
end

# Method 4: New with block
post = Post.new do |p|
  p.title = "Hello"
end
post.save
```

### Read

```ruby
# By primary key
Post[1]           # Returns model or nil
Post.with_pk!(1)  # Raises error if not found

# First matching record
Post.first                    # First in dataset
Post.first(title: "Hello")    # With filter
Post.first! { views > 100 }   # Raises if not found

# Find or create
Post.find_or_create(title: "Hello") { |p| p.body = "Default" }

# All records
Post.all                    # Array of models
Post.each { |p| puts p }   # Iterate
Post.map(:title)            # Array of titles
Post.select_map(:title)     # Only selects title column
Post.select_map([:id, :title])

# As hash
Post.as_hash(:id, :title)           # {1 => "A", 2 => "B"}
Post.as_hash                          # {1 => <Post>, 2 => <Post>}
Post.to_hash_groups(:author_id)       # Groups by key
```

### Update

```ruby
# Update and save
post.title = "New Title"
post.save

# Mass update without saving
post.set(title: "New", body: "Updated")

# Update and save in one
post.update(title: "New", body: "Updated")

# Update specific columns only
post.update_fields({title: "New"}, [:title])

# Update if exists, create if not
Post.insert_conflict(:update, {title: "Hello"}, {views: Sequel[:views] + 1})
```

### Delete

```ruby
# Single record
post.delete    # Bypass hooks, returns dataset
post.destroy   # Runs hooks, returns self

# Multiple records
Post.where(draft: true).delete      # Fast, no hooks
Post.where(draft: true).destroy    # Runs hooks on each

# Delete by primary key
Post.where(id: 1).delete
```

## Accessing Values

```ruby
post = Post[1]

# Attribute access
post.title       # => "Hello"
post[:title]     # => "Hello"
post.values      # => {:id => 1, :title => "Hello", ...}

# Check if column loaded
post.keys        # => [:id, :title, :body]

# Set values
post.title = "New"
post[:title] = "New"
```

## Dirty Tracking

```ruby
post = Post[1]
post.title = "New"

post.modified?           # => true
post.modified_columns    # => [:title]
post.previous_changes    # => {:title => ["Old", "New"]}
post.save_changes        # Only saves modified columns
```

## Dataset Methods

Model classes forward dataset methods:

```ruby
Post.where(draft: true)
Post.order(:created_at)
Post.limit(10)
Post.select(:id, :title)
Post.exclude(archived: true)

# Chain methods
Post.where(draft: false).order(:views).limit(5).all
```

## Custom Dataset Methods

```ruby
class Post < Sequel::Model
  dataset_module do
    where :published, draft: false
    where :popular, Sequel[:views] > 100
    order :by_date, :created_at
    select :brief, :id, :title, :summary
  end
end

# Usage
Post.published.by_date.brief.all
```

## Reloading

```ruby
post = Post[1]
# ... later, after potential external changes ...
post.refresh    # Reload from database
```

## Existence Checks

```ruby
Post.where(title: "Hello").empty?   # => true/false
Post.where(title: "Hello").any?     # => true/false
Post.exists?  # For model instances, checks if still in DB
```
