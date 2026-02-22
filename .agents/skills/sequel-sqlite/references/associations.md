# Associations

Sequel models support comprehensive association definitions.

## Association Types

### many_to_one (Belongs To)

```ruby
class Post < Sequel::Model
  many_to_one :author
  many_to_one :category
end

# Creates methods:
post.author       # => Author instance or nil
post.author = author
post.author_id    # => Integer
```

### one_to_many (Has Many)

```ruby
class Author < Sequel::Model
  one_to_many :posts
  one_to_many :drafts, class: :Post, conditions: { draft: true }
  one_to_many :recent_posts, class: :Post, 
    order: Sequel.desc(:created_at), limit: 5
end

# Creates methods:
author.posts                # => Dataset of posts
author.add_post(post)
author.remove_post(post)
author.remove_all_posts
author.posts_dataset        # Underlying dataset
```

### one_to_one (Has One)

```ruby
class Author < Sequel::Model
  one_to_one :profile, class: :UserProfile
end

# Creates methods:
author.profile        # => Profile instance or nil
author.profile = profile
```

### many_to_many (Has and Belongs to Many)

```ruby
class Post < Sequel::Model
  many_to_many :tags
end

class Tag < Sequel::Model
  many_to_many :posts
end

# Creates methods:
post.tags                    # => Array of tags
post.add_tag(tag)
post.remove_tag(tag)
post.remove_all_tags
post.tags_dataset            # Underlying dataset
```

Requires join table: `posts_tags` with `post_id` and `tag_id` columns.

### one_through_one

```ruby
class Post < Sequel::Model
  one_through_one :featured_tag, 
    class: :Tag, 
    order: Sequel.desc(:created_at),
    right_key: :tag_id
end
```

## Association Options

### Common Options

```ruby
class Post < Sequel::Model
  # Class name when different from association name
  many_to_one :writer, class: :Author
  
  # Foreign key name
  many_to_one :author, key: :written_by
  
  # Primary key (defaults to :id)
  many_to_one :author, primary_key: :user_id
  
  # Dataset conditions
  one_to_many :comments, conditions: { approved: true }
  
  # Ordering
  one_to_many :comments, order: Sequel.desc(:created_at)
  
  # Select specific columns
  one_to_many :comments, select: [:id, :body, :created_at]
  
  # Limit number of associated records
  one_to_many :recent_comments, class: :Comment, 
    order: Sequel.desc(:created_at), 
    limit: 10
end
```

### many_to_many Options

```ruby
class Post < Sequel::Model
  many_to_many :tags,
    join_table: :post_taggings,      # Default: posts_tags
    left_key: :post_id,               # Default: post_id
    right_key: :tag_id,               # Default: tag_id
    right_primary_key: :slug,         # Default: id
    conditions: { active: true }
end
```

## Eager Loading

Eager loading prevents N+1 queries by loading associations in bulk.

### Using eager

```ruby
# Load authors with their posts
authors = Author.eager(:posts).all
# 2 queries: 1 for authors, 1 for all their posts

# Access without additional queries
authors.each do |author|
  author.posts.each { |post| puts post.title }
end

# Multiple associations
Author.eager(:posts, :comments).all
Author.eager(:posts).eager(:profile).all

# Works with filtering
Author.where(active: true).eager(:posts).order(:name).all
```

### Cascading Eager Loading

```ruby
# Posts with authors, and authors' profiles
Post.eager(author: :profile).all

# Deep nesting
Author.eager(posts: { comments: :author }).all
# Loads: authors -> their posts -> posts' comments -> comments' authors
```

### Dynamic Eager Loading

```ruby
# Customize the eager loaded dataset with a proc
Post.eager(comments: proc { |ds| ds.where(approved: true) }).all

# Both customization and cascading
Post.eager(comments: { 
  proc { |ds| ds.where(approved: true) } => :author 
}).all
```

### eager_graph (Single Query)

Uses JOINs instead of separate queries:

```ruby
# One query with joins
authors = Author.eager_graph(:posts).all

# Useful for filtering/sorting on associated columns
Author.eager_graph(:posts).where(Sequel[:posts][:title] => "Hello").all

# Cascading
Author.eager_graph(posts: :comments).all
```

**Caution**: eager_graph with multiple `*_to_many` associations creates a cartesian product. Use carefully.

## Association Joins

Join based on association definition:

```ruby
# Inner join on association
Post.association_join(:author)
# => SELECT * FROM posts INNER JOIN authors ON authors.id = posts.author_id

# Left join
Post.association_left_join(:comments)

# Multiple associations
Post.association_join(:author, comments: :author)

# With filtering
Post.association_join(:author).where(Sequel[:authors][:name] => "John")
```

## Association Dataset Methods

### one_to_many / many_to_many

```ruby
author = Author[1]

# Filter associated records
author.posts_dataset.where(published: true).count

# Custom queries on association
author.posts_dataset.select(:title).order(:created_at).limit(5).all

# Mass operations
author.posts_dataset.where(draft: true).delete
author.posts_dataset.update(priority: 1)
```

## Association Callbacks

### Lifecycle Hooks

```ruby
class Post < Sequel::Model
  one_to_many :comments
  
  # Called when adding association
  def before_add_comment(comment)
    comment.post_id = id
  end
  
  # Called when removing association
  def before_remove_comment(comment)
    # Cleanup logic
  end
end
```

## Reciprocal Associations

Define both directions:

```ruby
class Author < Sequel::Model
  one_to_many :posts, reciprocal: :author
end

class Post < Sequel::Model
  many_to_one :author, reciprocal: :posts
end
```

This ensures caches are cleared in both directions when associations change.

## Through Associations

```ruby
class Author < Sequel::Model
  one_to_many :posts
  many_to_many :tags, through: :posts
  many_to_many :commenters, class: :User, through: :posts, right_key: :user_id, through_table: :comments
end
```
