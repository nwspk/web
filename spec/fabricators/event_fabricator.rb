Fabricator(:event) do
  name            "Test event"
  start_at        "2016-02-15 00:39:06"
  end_at          "2016-02-15 00:49:06"
  url             "http://example.com"
  location        "Kitchen"
  organiser_name  "Foo"
  organiser_email "foo@example.com"
  organiser_url   "http://example.com"
  description     "Lorem ipsum dolor sit amet"
  public          true
  status          1
  value           1000
end
