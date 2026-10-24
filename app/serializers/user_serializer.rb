class UserSerializer
  def self.render(user)
    {
      id: user.id,
      name: user.name,
      phone: user.phone,
      email: user.email,
      role: user.role,
      created_at: user.created_at
    }
  end
end
