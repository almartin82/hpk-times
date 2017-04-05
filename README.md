# hpk-times
heroku calculate stats and write rmd for hpk-diaspora

## things to do every year

* update `all_owners.csv` on s3 using [yahoo roster extract](https://github.com/almartin82/yahoo_roster_extract).  `teams.csv` can be renamed to `all_owners.csv`

```
f = open('/Users/almartin/Downloads/all_owners.csv','rb')
conn.upload('all_owners.csv', f, 'hpk')
```