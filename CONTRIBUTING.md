# Contributing <!-- omit in toc -->

First of all, thank you for contributing to MeiliSearch! The goal of this document is to provide everything you need to know in order to contribute to MeiliSearch and its different integrations.

- [Hacktoberfest](#hacktoberfest)
- [Assumptions](#assumptions)
- [How to Contribute](#how-to-contribute)
- [Development Workflow](#development-workflow)
- [Git Guidelines](#git-guidelines)
- [Release Process (for internal team only)](#release-process-for-internal-team-only)

## Hacktoberfest

It's [Hacktoberfest month](https://blog.meilisearch.com/contribute-hacktoberfest-2021/)! 🥳

🚀 If your PR gets accepted it will count into your participation to Hacktoberfest!

✅ To be accepted it has either to have been merged, approved or tagged with the `hacktoberfest-accepted` label.

🧐 Don't forget to check the [quality standards](https://hacktoberfest.digitalocean.com/resources/qualitystandards)! Low-quality PRs might get marked as `spam` or `invalid`, and will not count toward your participation in Hacktoberfest.

## Assumptions

1. **You're familiar with [GitHub](https://github.com) and the [Pull Request](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/about-pull-requests)(PR) workflow.**
2. **You've read the MeiliSearch [documentation](https://docs.meilisearch.com) and the [README](/README.md).**
3. **You know about the [MeiliSearch community](https://docs.meilisearch.com/learn/what_is_meilisearch/contact.html). Please use this for help.**

## How to Contribute

1. Make sure that the contribution you want to make is explained or detailed in a GitHub issue! Find an [existing issue](https://github.com/meilisearch/meilisearch-rails/issues/) or [open a new one](https://github.com/meilisearch/meilisearch-rails/issues/new).
2. Once done, [fork the meilisearch-rails repository](https://help.github.com/en/github/getting-started-with-github/fork-a-repo) in your own GitHub account. Ask a maintainer if you want your issue to be checked before making a PR.
3. [Create a new Git branch](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/creating-and-deleting-branches-within-your-repository).
4. Review the [Development Workflow](#development-workflow) section that describes the steps to maintain the repository.
6. Make the changes on your branch.
7. [Submit the branch as a PR](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/creating-a-pull-request-from-a-fork) pointing to the `main` branch of the main meilisearch-rails repository. A maintainer should comment and/or review your Pull Request within a few days. Although depending on the circumstances, it may take longer.<br>
 We do not enforce a naming convention for the PRs, but **please use something descriptive of your changes**, having in mind that the title of your PR will be automatically added to the next [release changelog](https://github.com/meilisearch/meilisearch-rails/releases/).

## Development Workflow

### Setup <!-- omit in toc -->

```bash
bundle install
```

### Tests <!-- omit in toc -->

Set the credentials of the MeiliSearch instance as environment variables.

```
MEILISEARCH_HOST="http://127.0.0.1:7700"
MEILISEARCH_API_KEY="masterKey"
```

Each PR should pass the tests to be accepted.

```bash
# Tests
docker pull getmeili/meilisearch:latest # Fetch the latest version of MeiliSearch image from Docker Hub
docker run -p 7700:7700 getmeili/meilisearch:latest ./meilisearch --master-key=masterKey --no-analytics=true
bundle exec rspec
# Launch a single test in a specific file
bundle exec rspec spec/integration_spec.rb -e 'should include _formatted object'
# Launch tests in a specific folder or file 
bundle exec rspec spec/integration_spec.rb
```

### Linter <!-- omit in toc -->

Each PR should pass the linter to be accepted.

```bash
# Check the linter errors
bundle exec rubocop lib/ spec/
# Auto-correct the linter errors
bundle exec rubocop -a lib/ spec/
```

If you think the remaining linter errors are acceptable, do not add any `rubocop` in-line comments in the code.<br>
This project uses a `rubocop_todo.yml` file that is generated. Do not modify this file manually.<br>
To update it, run the following command:

```bash
bundle exec rubocop --auto-gen-config
```

### Playground <!-- omit in toc -->

First, you need to run a MeiliSearch instance:

```bash
docker run -p 7700:7700 getmeili/meilisearch:latest ./meilisearch --no-analytics=true
```

To test directly your changes in `meilisearch-rails`, you can run the Rails playground:

```bash
cd playground
bundle install
bundle exec rails db:create
bundle exec rails db:migrate
bundle exec rails db:seed
bundle exec rails webpacker:install
bundle exec rails server
```
 ⚠️ Set your MeiliSearch credentials by modifying the file [`playground/config/initializers/meilisearch.rb`](/playground/config/initializers/meilisearch.rb)

## Git Guidelines

### Git Branches <!-- omit in toc -->

All changes must be made in a branch and submitted as PR.
We do not enforce any branch naming style, but please use something descriptive of your changes.

### Git Commits <!-- omit in toc -->

As minimal requirements, your commit message should:
- be capitalized
- not finish by a dot or any other punctuation character (!,?)
- start with a verb so that we can read your commit message this way: "This commit will ...", where "..." is the commit message.
  e.g.: "Fix the home page button" or "Add more tests for create_index method"

We don't follow any other convention, but if you want to use one, we recommend [this one](https://chris.beams.io/posts/git-commit/).

### GitHub Pull Requests <!-- omit in toc -->

Some notes on GitHub PRs:

- [Convert your PR as a draft](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/changing-the-stage-of-a-pull-request) if your changes are a work in progress: no one will review it until you pass your PR as ready for review.<br>
  The draft PR can be very useful if you want to show that you are working on something and make your work visible.
- The branch related to the PR must be **up-to-date with `main`** before merging. Fortunately, this project [integrates a bot](https://github.com/meilisearch/integration-guides/blob/main/guides/bors.md) to automatically enforce this requirement without the PR author having to do it manually.
- All PRs must be reviewed and approved by at least one maintainer.
- The PR title should be accurate and descriptive of the changes. The title of the PR will be indeed automatically added to the next [release changelogs](https://github.com/meilisearch/meilisearch-rails/releases/).

## Release Process (for internal team only)

MeiliSearch tools follow the [Semantic Versioning Convention](https://semver.org/).

### Automation to Rebase and Merge the PRs <!-- omit in toc -->

This project integrates a bot that helps us manage pull requests merging.<br>
_[Read more about this](https://github.com/meilisearch/integration-guides/blob/main/guides/bors.md)._

### Automated Changelogs <!-- omit in toc -->

This project integrates a tool to create automated changelogs.<br>
_[Read more about this](https://github.com/meilisearch/integration-guides/blob/main/guides/release-drafter.md)._

### How to Publish the Release <!-- omit in toc -->

⚠️ Before doing anything, make sure you got through the guide about [Releasing an Integration](https://github.com/meilisearch/integration-guides/blob/main/guides/integration-release.md).

Make a PR modifying the file [`lib/meilisearch/version.rb`](/lib/meilisearch/version.rb) with the right version.

```ruby
VERSION = 'X.X.X' 
```

Once the changes are merged on `main`, you can publish the current draft release via the [GitHub interface](https://github.com/meilisearch/meilisearch-rails/releases).

A GitHub Action will be triggered and push the package to [RubyGems](https://rubygems.org/gems/meilisearch-rails).

<hr>

Thank you again for reading this through, we can not wait to begin to work with you if you made your way through this contributing guide ❤️
