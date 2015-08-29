[![Gem Version](https://badge.fury.io/rb/slack_notification_generator.svg)](http://badge.fury.io/rb/slack_notification_generator)
[![Dependency Status](https://gemnasium.com/jasonhutchens/slack_notification_generator.png)](https://gemnasium.com/jasonhutchens/slack_notification_generator)

Slack Notification Generator
============================

Sends a notification to a Slack channel to indicate that a branch of your project has just been deployed by your CI system.

Usage
-----

Define the following environments in your CI system.

* `CI_BRANCH`: the name of the branch being built (such as "develop" or "master")
* `SLACK_HOOK`: the URL Slack gave you when you added the webhook integration (required)
* `SLACK_REPO`: an optional URL to your GitHub repo (for adding links to PRs)
* `SLACK_JIRA`: an optional URL to your JIRA instance (for adding links to issues)
* `SLACK_USER`: the user to post the notification as (defaults to "Notification")
* `SLACK_ICON`: the emoji for the user's avatar (defaults to ":bell:")
* `SLACK_CHAN`: the channel to post the notification to (defaults to "#general")
* `SLACK_NAME`: an optional name for your project

When your CI system deploys your project, run:

```
$ slack_notification_generator [HEAD]
```

Specify an argument of `HEAD` if you want to generate a notification relative to the latest tag. Otherwise it will be assumed that you want to generate a notification relative to the most recent pair of tags (for example, you may have tagged `master` before triggering a deploy to production).

Assumptions
-----------

We assume the following:

* you practice something like git-flow, with `develop`, `master` and `release` branches
* you use pull requests to merge most of your work to `develop`
* you tag `master` whenever you update production
* you use JIRA, and add JIRA commands to your git messages to link to issues and log time

Example
-------

(TBD)

Copyright
---------

Copyright (c) 2015 Jason Hutchens. See UNLICENSE for further details.
