require 'sinatra'
require 'json'
require 'config'
require 'octokit'
require 'net/http'
require 'cisco_spark'

set :root, File.dirname(__FILE__)
register Config

CiscoSpark.configure do |config|
  config.api_key = Settings.spark_api_key
end

def possible_reviewers(github_client, repository)
  all_members_json =
    github_client.collaborators(repository)
  all_members = all_members_json.map { |member| member[:login] }
  excluded_members = Settings.members_excluded_from_review
  all_members - excluded_members
end

def select_random_reviewers(github_client, author, repository)
  all_reviewers = possible_reviewers(github_client, repository) - [author]
  [all_reviewers.sample(Settings.number_of_reviewers)].flatten
end

def request_reviewers(reviewers, pull_api_url)
  request_reviewer_endpoint = pull_api_url + '/requested_reviewers'

  uri = URI(request_reviewer_endpoint)

  request = Net::HTTP::Post.new(uri.path)
  request['Accept'] = 'Accept: application/vnd.github.black-cat-preview+json'
  request['Authorization'] = "token #{Settings.github_token}"
  request.body = { 'reviewers': reviewers }.to_json

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  http.request(request)
end

def comment_with_reviewers_names(github_client, repo, pull_number, reviewers)
  references = reviewers.map do |e|
    e.dup.prepend('@')
  end
  comment =
    "Randomized reviewers for this pull request: #{references.join(', ')}"
  github_client.add_comment(repo, pull_number, comment)
end

def send_spark_message(reviewer_github_login, pull_url)
  matches = Settings.spark_emails.select do |e|
    e.github_login == reviewer_github_login
  end
  spark_email = matches.first.spark_email
  message = CiscoSpark::Message.new(
    text: "You have been select to review #{pull_url}",
    to_person_email: spark_email
  )
  message.persist
end

post '/pull_request' do


  pull_request_json = JSON.parse(request.body.read)
  return unless pull_request_json['action'] == 'opened'

  github_client = Octokit::Client.new(access_token: Settings.github_token)
  puts 'New pull request opened, randomizing reviewers'

  author = pull_request_json['pull_request']['user']['login']
  repository = pull_request_json['repository']['full_name']
  pull_api_url = pull_request_json['pull_request']['url']
  pull_url = pull_request_json['pull_request']['html_url']
  pull_number = pull_request_json['pull_request']['number']

  reviewers = select_random_reviewers(github_client, author, repository)

  response = request_reviewers(reviewers, pull_api_url)

  if response.is_a? Net::HTTPSuccess
    comment_with_reviewers_names(
      github_client, repository, pull_number, reviewers
    )
    reviewers.each { |r| send_spark_message(r, pull_url) }
    return 'Success'
  end
  'Failure'
end
