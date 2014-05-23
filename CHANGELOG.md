# Chef Client 10.x Changelog

## Unreleased

* `options` attribute of mount resource now supports lazy evaluation. (CHEF-5163)

## 10.32.2

* [**Phil Dibowitz**](https://github.com/jaymzh):
  Service Provider for MacOSX now supports `enable` and `disable`
* [**Phil Dibowitz**](https://github.com/jaymzh):
  Chef now gracefully handles corrupted cache files.
* [**Phil Dibowitz**](https://github.com/jaymzh):
  SIGTERM will once-more kill a non-daemonized chef-client (CHEF-5172)
* [**Phil Dibowitz**](https://github.com/jaymzh):
  bump up upper limit on json gem to 1.8.1 (CHEF-4632)


* pin sdoc to 0.3.0 due to solaris packaging issues.

## Last Release: 10.30.4 (02/18/2014)

http://www.getchef.com/blog/2014/02/18/chef-client-release-11-10-2-10-30-4/
