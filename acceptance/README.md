# Acceptance Testing for Chef Client
This folder contains acceptance tests that are required for Chef client
release readiness.

## Getting started
The tests use the _chef-acceptance_ gem as the high level framework.
All the gems needed to run these tests can be installed with Bundler.

```shell
chef/acceptance$ bundle install
```

To ensure everything is working properly, run:

```shell
chef/acceptance$ bundle exec chef-acceptance info
```

To run a particular test suite, do the following:
```shell
chef/acceptance$ bundle exec chef-acceptance test TEST_SUITE
```

### Important Note!

Before running chef-acceptance, you *MUST* do the following on your current session:

```
export APPBUNDLER_ALLOW_RVM=true
```
