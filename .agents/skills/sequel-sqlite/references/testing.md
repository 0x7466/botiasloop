# Testing

Testing Sequel models and queries effectively.

## Transaction Rollback Pattern

Wrap tests in transactions that roll back to keep database clean:

```ruby
RSpec.describe Post do
  # Rollback after each test
  around(:each) do |example|
    DB.transaction(rollback: :always) do
      example.run
    end
  end
  
  describe "#create" do
    it "creates a post" do
      post = Post.create(title: "Hello")
      expect(Post.count).to eq(1)
      # Transaction rolls back, no cleanup needed
    end
  end
end
```

### Alternative: before(:each)

```ruby
RSpec.describe Post do
  before(:each) do
    @transaction = DB.transaction(rollback: :always, savepoint: true)
  end
  
  after(:each) do
    @transaction.rollback if @transaction
  end
end
```

## Test Data Setup

### Factories

```ruby
# spec/factories.rb or spec/support/factories.rb
module Factories
  def create_post(attrs = {})
    Post.create({
      title: "Test Post",
      body: "Test body",
      author: create_author
    }.merge(attrs))
  end
  
  def create_author(attrs = {})
    Author.create({
      name: "Test Author",
      email: "test@example.com"
    }.merge(attrs))
  end
end

RSpec.configure do |config|
  config.include Factories
end
```

### Traits Pattern

```ruby
def create_draft_post(attrs = {})
  create_post({ draft: true, published: false }.merge(attrs))
end

def create_published_post(attrs = {})
  create_post({ draft: false, published: true }.merge(attrs))
end
```

## Testing Models

### CRUD Operations

```ruby
RSpec.describe Post do
  around { |e| DB.transaction(rollback: :always) { e.run } }
  
  describe "validations" do
    it "requires title" do
      post = Post.new(title: "")
      expect(post.valid?).to be false
      expect(post.errors.on(:title)).to include("can't be empty")
    end
    
    it "creates with valid attributes" do
      expect {
        Post.create(title: "Hello", body: "World")
      }.to change { Post.count }.by(1)
    end
  end
  
  describe "#update" do
    let(:post) { create_post }
    
    it "updates attributes" do
      post.update(title: "New Title")
      expect(post.reload.title).to eq("New Title")
    end
  end
  
  describe "#destroy" do
    let!(:post) { create_post }
    
    it "removes the record" do
      expect { post.destroy }.to change { Post.count }.by(-1)
    end
    
    it "runs destroy hooks" do
      expect_any_instance_of(Post).to receive(:before_destroy)
      post.destroy
    end
  end
end
```

### Testing Hooks

```ruby
RSpec.describe Post do
  describe "hooks" do
    it "sets slug before create" do
      post = Post.create(title: "Hello World")
      expect(post.slug).to eq("hello-world")
    end
    
    it "updates timestamp on save" do
      post = create_post
      original_time = post.updated_at
      sleep 1
      post.update(title: "New")
      expect(post.updated_at).to be > original_time
    end
  end
end
```

### Testing Associations

```ruby
RSpec.describe Author do
  let(:author) { create_author }
  
  describe "#posts" do
    it "returns posts" do
      post1 = create_post(author: author)
      post2 = create_post(author: author)
      create_post  # Different author
      
      expect(author.posts).to contain_exactly(post1, post2)
    end
    
    it "adds posts" do
      post = create_post
      expect { author.add_post(post) }.to change { author.posts.count }.by(1)
      expect(post.author).to eq(author)
    end
  end
  
  describe "eager loading" do
    it "avoids N+1 queries" do
      3.times { create_post(author: create_author) }
      
      queries = []
      DB.loggers << Logger.new(StringIO.new).tap { |l| l.level = Logger::DEBUG }
      
      # Should execute only 2 queries, not 4
      Author.eager(:posts).all.each do |author|
        author.posts.to_a
      end
    end
  end
end
```

## Testing Queries

### Dataset Testing

```ruby
RSpec.describe "Post queries" do
  around { |e| DB.transaction(rollback: :always) { e.run } }
  
  before do
    create_post(title: "Ruby Tips", draft: false, views: 100)
    create_post(title: "Rails Guide", draft: true, views: 50)
    create_post(title: "Sequel Docs", draft: false, views: 200)
  end
  
  describe ".published" do
    it "returns non-draft posts" do
      posts = Post.where(draft: false).all
      expect(posts.map(&:title)).to contain_exactly("Ruby Tips", "Sequel Docs")
    end
  end
  
  describe ".popular" do
    it "returns posts with views > 100" do
      posts = Post.where { views > 100 }.all
      expect(posts.map(&:title)).to eq(["Sequel Docs"])
    end
  end
  
  describe ".recent" do
    it "orders by created_at" do
      posts = Post.order(Sequel.desc(:created_at)).limit(2).all
      expect(posts.length).to eq(2)
    end
  end
end
```

### Testing Complex Filters

```ruby
RSpec.describe "Search functionality" do
  it "filters by date range" do
    old_post = create_post(created_at: Date.today - 30)
    new_post = create_post(created_at: Date.today)
    
    results = Post.where { created_at > Date.today - 7 }.all
    expect(results).to include(new_post)
    expect(results).not_to include(old_post)
  end
  
  it "performs OR queries" do
    post_a = create_post(title: "Ruby")
    post_b = create_post(body: "Ruby tips")
    post_c = create_post(title: "Python")
    
    results = Post.where(
      Sequel.or(title: "Ruby", body: /Ruby/)
    ).all
    
    expect(results).to include(post_a, post_b)
    expect(results).not_to include(post_c)
  end
end
```

## Testing Migrations

```ruby
RSpec.describe "Migrations" do
  let(:migrator) { Sequel::Migrator }
  
  before do
    # Use separate test database
    @test_db = Sequel.sqlite
  end
  
  it "creates tables" do
    migrator.run(@test_db, "db/migrations", target: 1)
    expect(@test_db.tables).to include(:posts)
  end
  
  it "adds columns" do
    migrator.run(@test_db, "db/migrations", target: 2)
    schema = @test_db.schema(:posts)
    column_names = schema.map(&:first)
    expect(column_names).to include(:slug)
  end
  
  it "is reversible" do
    # Migrate up
    migrator.run(@test_db, "db/migrations", target: 5)
    # Migrate down
    migrator.run(@test_db, "db/migrations", target: 0)
    expect(@test_db.tables).to be_empty
  end
end
```

## Mocking Database

### Stubbing Queries

```ruby
RSpec.describe MyService do
  it "finds posts" do
    allow(Post).to receive(:where).with(draft: false)
      .and_return(double(all: [Post.new(title: "Test")]))
    
    service = MyService.new
    result = service.find_published
    expect(result.first.title).to eq("Test")
  end
end
```

### Mocking Dataset

```ruby
ds = Sequel::Dataset.new(DB)
allow(ds).to receive(:where).and_return(ds)
allow(ds).to receive(:all).and_return([{ id: 1 }])
allow(Post).to receive(:dataset).and_return(ds)
```

## Integration Testing

### Full Workflow

```ruby
RSpec.describe "Post workflow", type: :integration do
  around { |e| DB.transaction(rollback: :always) { e.run } }
  
  it "creates, updates, and deletes" do
    # Create
    post = Post.create(title: "Original")
    expect(post.id).to be_present
    
    # Update
    post.update(title: "Updated")
    expect(Post[post.id].title).to eq("Updated")
    
    # Delete
    post.destroy
    expect(Post[post.id]).to be_nil
  end
  
  it "handles associations" do
    author = Author.create(name: "John")
    post = Post.create(title: "Hello", author: author)
    
    expect(author.posts).to include(post)
    
    post.destroy
    expect(author.posts_dataset.count).to eq(0)
  end
end
```

## Performance Testing

```ruby
RSpec.describe "Query performance" do
  before do
    1000.times { create_post }
  end
  
  it "completes in reasonable time" do
    start = Time.now
    Post.where(draft: false).order(:created_at).limit(100).all
    elapsed = Time.now - start
    expect(elapsed).to be < 0.1  # 100ms
  end
  
  it "uses indexes" do
    # Check query plan (SQLite-specific)
    plan = DB.execute("EXPLAIN QUERY PLAN SELECT * FROM posts WHERE draft = 0")
    expect(plan.join).to match(/USING INDEX|COVERING INDEX/)
  end
end
```

## Shared Contexts

```ruby
RSpec.shared_context "with posts" do
  let!(:draft_post) { create_post(draft: true) }
  let!(:published_post) { create_post(draft: false) }
end

RSpec.describe Post do
  include_context "with posts"
  
  around { |e| DB.transaction(rollback: :always) { e.run } }
  
  it "filters drafts" do
    drafts = Post.where(draft: true).all
    expect(drafts).to contain_exactly(draft_post)
  end
end
```

## Test Database Setup

```ruby
# spec/spec_helper.rb
require "sequel"

# Connect to in-memory test database
TEST_DB = Sequel.sqlite

# Load schema
Sequel::Migrator.run(TEST_DB, "db/migrations")

# Configure RSpec
RSpec.configure do |config|
  config.around(:each) do |example|
    TEST_DB.transaction(rollback: :always, savepoint: true) do
      example.run
    end
  end
end
```
