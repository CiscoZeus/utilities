## Random-reviewer

This is a small sinatra application used as a github web hook to select a number of reviewers
at random for pull requests.

## Installation

Install ruby 2.2.4

Install bundler
`gem install bundler`

Install the dependencies
`bundle install`

## Running

Create the configuration file on the config folder:

`mv settings.sample.yml seetings.yml`

Remember to set the github token, it needs to have read:org and repo permissions

To run it for development just run:

`bundle exec ruby routes.rb`

You might want to use [ngrok](https://ngrok.com/), to expose your computer so github can send
requests to it

To run it on production just use your favorite application server (unicorn, passenger, uwsgi, etc)
