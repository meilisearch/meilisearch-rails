## Meilisearch::Rails playground 

**Use Docker to setup your environment.**

Run all the setup commands in a instance of the container `docker-compose run --rm playground bash` then:

- `bundle install`
- `yarn install`
- `bundle exec rails db:setup`

To start the app use:

`docker-compose up playground`

Then check http://0.0.0.0:3000 

You can run any other rails-related code in the container:

```bash
docker-compose run --rm playground bash
root@49ebb83ca4bf:/home/app# bundle exec rails c
Running via Spring preloader in process 28
Loading development environment (Rails 6.1.7)
irb(main):001:0> Book.count
   (1.2ms)  SELECT sqlite_version(*)
   (0.7ms)  SELECT COUNT(*) FROM "books"
=> 50
irb(main):002:0>
```
