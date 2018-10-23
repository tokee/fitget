# fitness.dk training statistics scraper

Simple script for extracting time, activity & place statistics for training sessions at the Danish fitness chain http://fitness.dk

This script is not affiliated with fitness.dk in any way. It uses no special processing beyond what a standard user-driven browser-based "login, check data, logout"-activity does.

Hacked together in a few hours by Toke Eskildsen - te@ekot.dk. Use as you see fit.

## Requirements

 * bash, wget
 * An account at fitness.dk

Only tested under Ubuntu 18.04. Should work under any Linux and probably also OS X. Might also work under Windows 10 with linux support?

## How the site works (so that the script can be fixed when it breaks)

As a customer of fitness.dk, all uses of any of its centres are tracked when the key-card is swiped. There is no tracking upon leaving a center as key-card swipe is not needed for that. The tracking data are available of the website, if a customer creates an account.

Data are not available through any known API, so screen scraping is needed to get them out automatically.

There is a calendar at https://www.fitnessdk.dk/info/training?month=10&year=2018 which requires login. As can be seen, the `month` and `year` are specified clearly. For the month January-October, both single-digit and two-digit zero-prefixed month-number works.

Login is done through the front page, where a form has the hidden field
```
<input type="hidden" name="form_build_id" value="form-XXX" />
```
The `XXX`-token is generated dynamically. Submitting the form activates a `POST` call to https://www.fitnessdk.dk/user with the parameters

 * `name=<login>`
 * `pass=<password>`
 * `form_build_id=<form-XXX_token_from_the_front_page>`
 * `form_id=user_login`
 * `op=Log+ind`
 
After this the relevant cookies are set for the session and the training data can be accessed.

## How to automatically extract the data

Thie idea is simple: Simulate the login using `wget` with cookies enabled, then iterate the wanted months & years and scrape the data.

This is exactly what `fitget.sh` does. It keeps the fetched data in `fitget.json` and tries to minimize the amount of requests for historical fitness data by looking at the latest entry from last fetch.

In order to use the script, the email and the password of the user must be stated. This can either be specified in a file called `fitget.conf` (see `sample_fitget.conf`) or directly as the script is called with `LOGIN="12a3456" PASSWORD="S3€R37" ./fitget.sh`.
