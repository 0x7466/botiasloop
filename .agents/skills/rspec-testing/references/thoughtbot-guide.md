# Thoughtbot RSpec Testing Guide Summary

Source: [thoughtbot/guides](https://github.com/thoughtbot/guides/tree/main/testing-rspec) - A guide for programming in style

## Core Principles

### Unit Testing
Tests should be fast, isolated, and test a single unit of code.

### Test Behavior, Not Implementation
Focus on what the code does, not how it does it:

```ruby
# Bad - tests implementation
it "calls the API client" do
  expect(api_client).to receive(:fetch)
  service.call
end

# Good - tests behavior
it "returns user data" do
  result = service.call
  expect(result).to include(name: "John")
end
```

### Arrange-Act-Assert
Structure tests with clear phases:

```ruby
it "calculates the total" do
  # Arrange
  order = Order.new(items: [item1, item2])
  
  # Act
  total = order.total
  
  # Assert
  expect(total).to eq(100)
end
```

## Testing Practices

### Use Describe Blocks
Organize tests with `describe` and `context`:

```ruby
describe Order do
  describe "#total" do
    context "with items" do
      it "sums the item prices"
    end
    
    context "with no items" do
      it "returns zero"
    end
  end
end
```

### Use Context for State
Use `context` to describe the state being tested:

```ruby
describe "#valid?" do
  context "when email is missing" do
    it "returns false"
  end
  
  context "when email is present" do
    it "returns true"
  end
end
```

### Avoid let! for Database
Prefer `let!` only when you need database records created before each example:

```ruby
# Good - lazy evaluation
let(:user) { FactoryBot.create(:user) }

# Use let! only when needed
let!(:user) { FactoryBot.create(:user) }  # Creates immediately
```

## Mocking Guidelines

### Mock at Boundaries
Mock external services and I/O, not internal objects:

```ruby
# Good - mock external API
allow(ExternalAPI).to receive(:fetch).and_return(response)

# Bad - mock internal collaborator
allow(service).to receive(:calculate).and_return(42)
```

### Use Verified Doubles
Prefer `instance_double` and `class_double` over `double`:

```ruby
let(:user) { instance_double(User, name: "John") }
```

### Stubbing Chains
Avoid stubbing long chains - it's a sign of tight coupling:

```ruby
# Bad - tight coupling
allow(user).to receive_message_chain(:account, :settings, :theme)

# Good - inject dependency
allow(user).to receive(:theme).and_return("dark")
```

## Test Data

### Use Factories
Use FactoryBot for creating test data:

```ruby
# Good
let(:user) { FactoryBot.create(:user) }

# Bad - manual setup
let(:user) do
  user = User.new
  user.name = "John"
  user.email = "john@example.com"
  user.save!
  user
end
```

### Traits for Variations
Use traits for different object states:

```ruby
factory :user do
  name { "Default" }
  
  trait :admin do
    role { "admin" }
  end
  
  trait :inactive do
    active { false }
  end
end

# Usage
let(:admin) { FactoryBot.create(:user, :admin) }
```

## Test Organization

### One Concept Per Test
Each test should verify one concept:

```ruby
# Bad - testing multiple things
it "validates presence and format of email" do
  user.email = nil
  expect(user).not_to be_valid
  
  user.email = "invalid"
  expect(user).not_to be_valid
end

# Good - separate tests
context "when email is blank" do
  it "is invalid"
end

context "when email format is invalid" do
  it "is invalid"
end
```

### Group Related Tests
Use nested `describe` blocks to group related tests:

```ruby
describe Order do
  describe "validations" do
    it { is_expected.to validate_presence_of(:total) }
  end
  
  describe "associations" do
    it { is_expected.to have_many(:items) }
  end
  
  describe "calculations" do
    describe "#total"
    describe "#tax"
  end
end
```

## Integration Tests

### Feature Specs
Use feature specs for end-to-end testing:

```ruby
feature "User signs in" do
  scenario "with valid credentials" do
    visit sign_in_path
    fill_in "Email", with: "user@example.com"
    fill_in "Password", with: "password"
    click_button "Sign in"
    
    expect(page).to have_content("Welcome")
  end
end
```

### JavaScript Testing
Tag specs that need JavaScript:

```ruby
scenario "with JavaScript", js: true do
  # ...
end
```

## Coverage

### Focus on Critical Paths
Prioritize testing:
1. Business logic
2. Edge cases
3. Error handling
4. Happy paths

### Don't Test Frameworks
Don't test Rails/RSpec itself:

```ruby
# Bad - testing Rails
it "has many orders" do
  expect(User.reflect_on_association(:orders).macro).to eq(:has_many)
end

# Use shoulda-matchers instead
it { is_expected.to have_many(:orders) }
```

## Additional Resources

- Full guide: [github.com/thoughtbot/guides](https://github.com/thoughtbot/guides/tree/main/testing-rspec)
- thoughtbot blog: [thoughtbot.com/blog/tags/testing](https://thoughtbot.com/blog/tags/testing)
- FactoryBot: [github.com/thoughtbot/factory_bot](https://github.com/thoughtbot/factory_bot)
