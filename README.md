# SearchableRecords

A barebones Rails gem that adds searchable functionality to ActiveRecord models.

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
class ActiveRecordExample < ApplicationRecord
  searchable
end
```

Currently, the `searchable` method is a no-op placeholder for future functionality.

## License

The gem is available as open source under the terms of the MIT License.