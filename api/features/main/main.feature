Feature: Primary
  In order for this website to work
  As an API user
  I can fetch the docs.jsonld

  Background:
    Given I add "Accept" header equal to "application/ld+json"
    And I add "Content-Type" header equal to "application/ld+json"

  Scenario: I can get the docs.jsonld endpoint
    When I send a "GET" request to "/docs.jsonld"
    Then the response status code should be 200
