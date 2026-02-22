# Querying

Sequel provides a powerful DSL for constructing SQL queries.

## Dataset Basics

Datasets are immutable and chainable:

```ruby
ds = DB[:posts]
ds = ds.where(draft: false)
ds = ds.order(:created_at)
ds = ds.limit(10)

# Only executes when retrieving results
posts = ds.all  # => Array of hashes
```

## Filtering with Where

### Basic Equality

```ruby
DB[:posts].where(id: 1)
DB[:posts].where(title: "Hello", draft: false)  # AND conditions
```

### Virtual Row Blocks

```ruby
# Use blocks for complex expressions
DB[:posts].where{ views > 100 }
DB[:posts].where{ (views > 100) & (draft == false) }
DB[:posts].where{ title =~ /hello/i }  # Regexp (PostgreSQL/MySQL)

# Operators
DB[:posts].where{ views > 100 }
DB[:posts].where{ views >= 100 }
DB[:posts].where{ views < 100 }
DB[:posts].where{ views <= 100 }
DB[:posts].where{ created_at =~ Date.today }  # Equality with =~
```

### Explicit Qualification

```ruby
# Use Sequel[] to qualify columns
DB[:posts].where(Sequel[:views] > 100)
DB[:posts].where(Sequel[:created_at] > Date.today - 7)

# Table qualification
DB[:posts].join(:authors, id: :author_id)
  .where(Sequel[:authors][:name] => "John")
```

### Inclusion

```ruby
# Range (BETWEEN)
DB[:posts].where(views: 100..500)      # Inclusive
DB[:posts].where(views: 100...500)     # Exclusive end

# Array/Set (IN)
DB[:posts].where(status: ["draft", "review"])
DB[:posts].where(id: Set[1, 2, 3])

# Dataset (subselect)
DB[:posts].where(author_id: DB[:authors].select(:id).where(active: true))
```

### Exclusion

```ruby
DB[:posts].exclude(draft: true)           # != or NOT IN
DB[:posts].exclude(id: [1, 2, 3])         # NOT IN
DB[:posts].exclude{ views < 100 }        # Block form
```

### Boolean Columns

```ruby
DB[:posts].where(:published)              # WHERE published (IS TRUE)
DB[:posts].exclude(:published)           # WHERE NOT published
DB[:posts].where(published: nil)        # IS NULL
DB[:posts].exclude(published: nil)       # IS NOT NULL
```

### Raw SQL Fragments

```ruby
DB[:posts].where(Sequel.lit("views > ?", 100))
DB[:posts].where(Sequel.lit("title LIKE ?", "%hello%"))
DB[:posts].where(Sequel.lit("created_at > :date", date: Date.today - 7))

# Combining with DSL
DB[:posts].where(draft: false)
  .where(Sequel.lit("views > (SELECT AVG(views) FROM posts)"))
```

## Ordering

```ruby
DB[:posts].order(:created_at)                    # ASC
DB[:posts].order(Sequel.desc(:created_at))        # DESC
DB[:posts].order(:author_id, Sequel.desc(:created_at))

# Override existing order
DB[:posts].order(:created_at).order(:title)      # Only :title

# Append/Prepend to order
DB[:posts].order(:author_id).order_append(:created_at)
DB[:posts].order(:author_id).order_prepend(:created_at)

# Remove order
DB[:posts].order(:created_at).unordered

# Reverse all
DB[:posts].order(:created_at).reverse
```

## Limit and Offset

```ruby
DB[:posts].limit(10)                 # First 10
DB[:posts].limit(10, 20)             # 10 rows starting at 21st
DB[:posts].limit(10).offset(20)      # Same as above

# Remove limit
DB[:posts].limit(10).unlimited
```

## Selecting Columns

```ruby
DB[:posts].select(:id, :title)
DB[:posts].select(Sequel[:id].as(:post_id))

# Override
DB[:posts].select(:id).select(:title)  # Only :title

# Append/Prepend
DB[:posts].select(:id).select_append(:title)
DB[:posts].select(:id).select_prepend(:title)

# Select all
DB[:posts].select(:id).select_all

# Distinct
DB[:posts].select(:author_id).distinct
```

## Grouping and Aggregations

```ruby
# Group
DB[:posts].group(:author_id)
DB[:posts].group(:author_id, :status)

# Group and count (convenience)
DB[:posts].group_and_count(:author_id)
# SELECT author_id, count(*) AS count FROM posts GROUP BY author_id

# Aggregates
DB[:posts].count                    # Total count
DB[:posts].count(:author_id)       # Non-null author_id count
DB[:posts].sum(:views)
DB[:posts].avg(:views)
DB[:posts].max(:views)
DB[:posts].min(:views)

# Combined
DB[:posts].select_group(:author_id)
  .select_append{ avg(:views).as(:avg_views) }

# Having
DB[:posts].group_and_count(:author_id)
  .having{ count.function.* >= 5 }
```

## Joins

```ruby
# Inner join
DB[:posts].join(:authors, id: :author_id)

# Left join
DB[:posts].left_join(:authors, id: :author_id)

# Explicit qualification (when ambiguous)
DB[:posts].join(:authors, id: :author_id)
  .join(:comments, post_id: Sequel[:posts][:id])

# Using (when column names match)
DB[:posts].join(:authors, [:author_id])

# Natural join
DB[:posts].natural_join(:authors)

# Cross join
DB[:posts].cross_join(:tags)

# Block form for complex conditions
DB[:posts].join(:authors, id: :author_id) do |j, lj, js|
  Sequel[j][:created_at] > Sequel[lj][:created_at]
end
```

## Subqueries

```ruby
# As scalar
DB[:posts].where{ views > DB[:posts].select{ avg(views) } }

# As derived table
DB[:posts].where(author_id: DB[:authors].select(:id).where(active: true))

# From self
DB[:posts].order(:created_at).limit(10).from_self.group(:author_id)
```

## Complex Combinations

```ruby
# AND conditions
DB[:posts].where(draft: false, published: true)
DB[:posts].where(draft: false).where(published: true)

# OR conditions
DB[:posts].where(Sequel.or(draft: false, published: true))
DB[:posts].where{ (draft == false) | (published == true) }

# Complex boolean logic
DB[:posts].where(
  Sequel.or(
    { draft: false },
    Sequel.and({ published: true }, Sequel[:views] > 100)
  )
)

# With blocks
DB[:posts].where{ 
  ((draft == false) & (published == true)) | (featured == true) 
}
```

## Execution Methods

```ruby
# Retrieval
ds.all                    # Array of all rows
ds.each { |row| ... }    # Iterate
ds.first                  # First row
ds.first(5)              # Array of first 5
ds.last                   # Last row (requires order)
ds.single_record          # Raises if multiple rows
ds.single_value           # First column of first row

# Existence
ds.empty?                 # No rows?
ds.any?                   # Has rows?

# SQL generation
ds.sql                    # Get SQL string
```
