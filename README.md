# SearchableRecords

A Rails gem that adds substring search functionality to ActiveRecord models through a simple `searchable` class method.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'searchable_records'
```

And then execute:

    $ bundle install

## Usage

To make a model searchable, simply add the `searchable` method to your model:

```ruby
class User < ApplicationRecord
  searchable
end
```

This enables substring search across all string and text columns:

```ruby
# Search for users with "john" in any text field
User.search("john")          # Finds "John Doe", "Johnny", etc.

# Case-insensitive matching
User.search("JOHN")          # Same results as above

# Get list of searchable fields
User.searchable_fields       # Returns ["name", "email", "bio", ...]
```

## Features

- **Substring matching**: Finds partial matches within text
- **Multi-column search**: Searches all string/text columns automatically  
- **Case-insensitive**: Works regardless of case
- **Secure**: Uses parameterized queries to prevent SQL injection
- **Type-safe**: Only searches appropriate column types (string, text)

## Examples

```ruby
class Article < ApplicationRecord
  searchable
end

# Find articles containing "ruby" in title or content
Article.search("ruby")

# Find articles with "2024" anywhere in text fields  
Article.search("2024")

# Empty/nil queries return no results
Article.search("")           # Returns empty relation
Article.search(nil)          # Returns empty relation
```

## License

The gem is available as open source under the terms of the MIT License.