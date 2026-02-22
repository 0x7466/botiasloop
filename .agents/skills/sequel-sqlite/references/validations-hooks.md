# Validations & Hooks

Sequel provides model-level data integrity through validations and lifecycle hooks.

## Validations

### Basic Validation

```ruby
class Post < Sequel::Model
  def validate
    super
    errors.add(:title, "can't be empty") if title.nil? || title.empty?
    errors.add(:views, "must be positive") if views && views < 0
  end
end
```

### Validation Errors

```ruby
post = Post.new
t post.valid?       # => false
post.errors         # => {:title => ["can't be empty"]}
post.errors.on(:title)  # => ["can't be empty"]
post.errors.full_messages  # => ["title can't be empty"]

post.save           # Raises Sequel::ValidationFailed by default
post.save(raise_on_failure: false)  # Returns nil instead
```

### Common Validation Patterns

```ruby
class Post < Sequel::Model
  def validate
    super
    
    # Presence
    errors.add(:title, "is required") if title.to_s.empty?
    
    # Format
    errors.add(:email, "is invalid") unless email =~ /\A[^@]+@[^@]+\.[^@]+\z/
    
    # Uniqueness (with race condition caveat)
    if title && Post.where(title: title).exclude(id: id).any?
      errors.add(:title, "is already taken")
    end
    
    # Length
    errors.add(:title, "is too long") if title && title.length > 100
    
    # Numeric range
    errors.add(:rating, "must be 1-5") unless rating && (1..5).include?(rating)
    
    # Inclusion
    errors.add(:status, "is invalid") unless %w[draft published archived].include?(status)
    
    # Custom condition
    errors.add(:published_at, "required for published posts") if published && !published_at
  end
end
```

**Note**: Uniqueness validations have race conditions. Prefer database unique constraints for true uniqueness enforcement.

## Hooks (Callbacks)

Sequel provides hooks that wrap database operations.

### Available Hooks

```ruby
class Post < Sequel::Model
  # Validation hooks
  def before_validation
    super
    # Normalize data before validation
    self.title = title.to_s.strip if title
  end
  
  def after_validation
    super
    # Post-validation logic
  end
  
  # Save hooks (called for both create and update)
  def before_save
    super
    self.updated_at = Time.now
  end
  
  def after_save
    super
    # Post-save logic like clearing caches
  end
  
  # Create hooks
  def before_create
    super
    self.created_at ||= Time.now
    self.slug ||= title.to_s.downcase.gsub(/\s+/, '-')
  end
  
  def after_create
    super
    # Notification, logging, etc.
  end
  
  # Update hooks
  def before_update
    super
    # Logic before update
  end
  
  def after_update
    super
    # Logic after update
  end
  
  # Destroy hooks
  def before_destroy
    super
    # Cleanup, check dependencies
    raise Sequel::Error, "Can't delete published posts" if published
  end
  
  def after_destroy
    super
    # Post-destruction cleanup
  end
end
```

### Hook Execution Order

**Create**: `before_validation` → `after_validation` → `before_save` → `before_create` → **INSERT** → `after_create` → `after_save`

**Update**: `before_validation` → `after_validation` → `before_save` → `before_update` → **UPDATE** → `after_update` → `after_save`

**Destroy**: `before_destroy` → **DELETE** → `after_destroy`

### Important: Call super

Always call `super` in hook methods to ensure plugin functionality works:

```ruby
def before_save
  super  # Don't forget this!
  self.updated_at = Time.now
end
```

### Conditionally Skipping Hooks

```ruby
# Skip all hooks
post.save(validate: false)  # Skip validations
post.delete                  # Skip destroy hooks

# Model-level disable
Post.skip_hooks do
  Post.where(draft: true).destroy
end
```

## Practical Examples

### Soft Deletes

```ruby
class Post < Sequel::Model
  def before_destroy
    super
    self.deleted_at = Time.now
    save
    throw(:halt, false)  # Prevent actual deletion
  end
  
  # Override default dataset to exclude deleted
  def self.default_dataset
    super.where(deleted_at: nil)
  end
  
  # Access all including deleted
  def self.with_deleted
    dataset.unfiltered
  end
end
```

### Auto-Slugs

```ruby
class Post < Sequel::Model
  def before_create
    super
    self.slug = generate_slug
  end
  
  def before_update
    super
    self.slug = generate_slug if title_changed?
  end
  
  private
  
  def generate_slug
    title.to_s.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')
  end
  
  def title_changed?
    column_changed?(:title)
  end
end
```

### Audit Trail

```ruby
class Post < Sequel::Model
  def after_create
    super
    AuditLog.create(action: "created", record_type: "Post", record_id: id, data: values)
  end
  
  def after_update
    super
    AuditLog.create(action: "updated", record_type: "Post", record_id: id, 
                    data: { previous: previous_changes, current: changed_columns })
  end
  
  def after_destroy
    super
    AuditLog.create(action: "deleted", record_type: "Post", record_id: id)
  end
end
```

### Cache Invalidation

```ruby
class Post < Sequel::Model
  many_to_one :author
  
  def after_save
    super
    Cache.delete("author:#{author_id}:posts")
    Cache.delete("post:#{id}")
  end
  
  def after_destroy
    super
    Cache.delete("author:#{author_id}:posts")
    Cache.delete("post:#{id}")
  end
end
```

## Validation Plugins

Sequel ships with validation helpers:

```ruby
class Post < Sequel::Model
  plugin :validation_helpers
  
  def validate
    super
    validates_presence [:title, :body]
    validates_unique :slug
    validates_format /\A[\w-]+\z/, :slug
    validates_integer :views
    validates_length_range 10..100, :title
    validates_includes %w[draft published archived], :status
  end
end
```

Load with: `Sequel::Model.plugin :validation_helpers` or per-model.
