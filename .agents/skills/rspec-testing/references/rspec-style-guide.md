# RSpec Style Guide Summary

Source: [rspec.rubystyle.guide](https://rspec.rubystyle.guide/) by the RuboCop team

## Layout

### Empty Lines
- **No empty lines** after `describe`/`context` descriptions
- **One empty line** between example groups
- **One empty line** after `let`/`subject`/`before` blocks
- Group `let`/`subject` together, separate from hooks

### Structure Order
1. `subject` (if using)
2. `let`/`let!` declarations
3. `before`/`after` hooks
4. Example groups (`describe`/`context`)
5. Examples (`it`/`specify`)

## Example Group Structure

### Leading Subject
Place `subject` at the top of the example group:

```ruby
describe Article do
  subject { FactoryBot.create(:article) }
  
  describe "#summary" do
    # ...
  end
end
```

### Context Usage
Use `context` for scenarios, `describe` for methods:

```ruby
describe "#summary" do
  context "when article is published" do
    it "returns the summary" do
      # ...
    end
  end
  
  context "when article is draft" do
    it "returns nil" do
      # ...
    end
  end
end
```

### Context Cases
Start context descriptions with:
- "when..."
- "with..."
- "without..."
- "if..."
- "unless..."
- "for..."

### Let vs Instance Variables
Always use `let` over instance variables:

```ruby
# Bad
before { @article = Article.new }

# Good
let(:article) { Article.new }
```

### Avoid :context Hooks
Don't use `before(:context)` or `after(:context)` - they don't wrap transactions properly and can cause test pollution.

## Example Structure

### Single Expectation
Prefer one expectation per example. Use `aggregate_failures` for related checks:

```ruby
# Good
it "returns the summary" do
  expect(article.summary).to eq("Summary text")
end

# Acceptable for related fields
it "returns all fields" do
  aggregate_failures do
    expect(result.name).to eq("Name")
    expect(result.email).to eq("email@example.com")
  end
end
```

### Subject Usage
Use named subjects for clarity:

```ruby
subject(:article) { FactoryBot.create(:article) }

it "is published" do
  expect(article).to be_published
end
```

### Don't Stub Subject
Don't mock or stub the subject - test the real object.

### Implicit Block Expectations
Use implicit block syntax when possible:

```ruby
# Good
expect { user.save }.to change(User, :count).by(1)

# Instead of
expect { user.save }.to change { User.count }.by(1)
```

## Naming

### Example Descriptions
- Don't use "should" in descriptions
- Keep descriptions short
- Focus on behavior, not implementation

```ruby
# Bad
it "should return the summary"

# Good
it "returns the summary"
```

### Method Descriptions
- Instance methods: `"#method_name"`
- Class methods: `".method_name"`

## Matchers

### Predicate Matchers
Use predicate matchers for boolean methods:

```ruby
expect(user).to be_active      # calls user.active?
expect(user).not_to be_admin   # calls user.admin?
```

### Built-in Matchers
Use specific matchers over generic ones:

```ruby
# Good
expect(array).to be_empty
expect(string).to be_present
expect(number).to be_zero
expect(collection).to include(item)

# Avoid
expect(array.empty?).to be true
```

### Avoid any_instance_of
Don't use `any_instance_of` - it's a code smell indicating design issues.

## Rails-Specific

### Models
- Don't mock models in model specs - test the real thing
- Use factories over fixtures
- Test validations separately

### Controllers
- Mock models in controller specs
- Focus on controller behavior, not model logic
- Test response status, templates, and instance variables

### Views
- Mock models
- Test rendered content
- Use Capybara matchers for integration

## Recommendations

### Use FactoryBot
Use factories instead of fixtures for test data:

```ruby
let(:user) { FactoryBot.create(:user) }
```

### Needed Data Only
Create only the data needed for the test:

```ruby
# Good - creates minimal data
let(:user) { FactoryBot.create(:user, name: "Test") }

# Bad - creates unnecessary associations
let(:user) { FactoryBot.create(:user, :with_orders, :with_addresses) }
```

### Time Testing
Use time helpers instead of timecop:

```ruby
freeze_time do
  expect(event.starts_at).to eq(Time.current)
end
```

## Additional Resources

- Full guide: [rspec.rubystyle.guide](https://rspec.rubystyle.guide/)
- RuboCop RSpec: [github.com/rubocop/rubocop-rspec](https://github.com/rubocop/rubocop-rspec)
