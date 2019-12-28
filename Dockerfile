FROM ruby:2.4.1

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1
ENV LANG=en_US.UTF-8

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .
EXPOSE 8080

CMD ["ruby", "./blog.rb"]
