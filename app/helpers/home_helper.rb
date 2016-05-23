module HomeHelper
  def gravatar_url(email)
    base_url      = "//gravatar.com/avatar/"
    hashed_email  = Digest::MD5.hexdigest(email)

    [base_url, hashed_email].join
  end
end
