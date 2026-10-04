# Application Guidelines

## 1. Tech Stack & Environment
* **Framework:** Ruby on Rails 8.x
* **Database:** SQLite
* **CSS Preprocessor:** Tailwind
* **Testing:** RSpec + FactoryBot (No Minitest)
* **Linter:** RuboCop
* **Framework Features** Hotwire with Turbo and Stimulus for dynamic pages.

## 2. Core Commands
Always prefix Ruby commands with `bin/` execution context.

* **Run Server:** `bin/dev` (or `bin/rails server` if Tailwind watcher not active)
* **Console:** `bin/rails console`
* **Run Database Migrations:** `bin/rails db:migrate`
* **Run All Tests:** `bin/rspec`
* **Run Single Test File:** `bin/rspec spec/models/user_spec.rb`
* **Run Linter:** `bin/rubocop -A`

## 3. Code Style & Architecture
* **The Rails Way:** Keep controllers thin. Put business logic in Models or dedicated Service Objects (`app/services/`).
* **Database Constraints:** Always enforce constraints in migrations (e.g., `null: false`, `foreign_key: true`, unique indexes) in tandem with Model validations.
* **Modern Ruby:** Use shorthand hash syntax `{ key: value }`, safe navigation `&.`, and endless method definitions for simple oneliners.
* **RuboCop compliance:** Code must pass `bin/rubocop` with zero warnings before completion.
* **Authorization and Authentication:** No Authorization or Authentication layers. Any action of any controller is available to anyone.

## 4. Test Style
* Group tests with descriptive `describe` and `context` blocks.
* Prefer `FactoryBot.create` over fixtures.
* Write Request specs for APIs/controllers and Model specs for validations/scopes.

