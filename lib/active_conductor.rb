require "active_model"
require "forwardable"

# The ActiveConductor is an implementation of the conductor pattern.
#
# The conductor pattern unifies some models into a single object and
# cleans up controller code massively.
#
# @example
#   class SignupConductor < ActiveConductor
#     def models
#       [user, profile]
#     end
#
#     def user
#       @user ||= User.new
#     end
#
#     def profile
#       @profile ||= Profile.new
#     end
#
#     conduct :user, :first_name, :last_name
#     conduct :profile, :image
#   end
#
# @author Scott Taylor
# @author Michael Kessler
#
class ActiveConductor
  include ActiveModel::Conversion
  include ActiveModel::Validations
  include ActiveModel::Serialization

  extend ActiveModel::Naming
  extend ActiveModel::Translation
  extend Forwardable

  attr_accessor :conducted_attributes

  class << self

    # Conduct an attribute from the conductor to the associated
    # model.
    #
    # @example Conduct an the email and password attribute to the user model
    #   conduct :user, :email, :password
    #
    # @param model [Symbol] the name of the model
    # @param *attributes [Symbol] one or more model attribute name
    #
    def conduct(model, *attributes)
      conducted_attributes.concat(attributes.map(&:to_sym))

      attributes.each do |attr|
        def_delegator model, attr
        def_delegator model, "#{attr}="
      end
    end

    # Remembers the conducted attributes
    #
    # @return [Array] the attributes
    #
    def conducted_attributes
      @conducted_attributes ||= []
    end

  end

  # Initialize the conductor with optional attributes.
  #
  # @param attributes [Hash] the attributes hash
  # @return [ActiveConductor] the created conductor
  #
  def initialize(attributes={})
    self.attributes = attributes
  end

  # Set the attributes on the associated models.
  #
  # @param attributes [Hash] the attributes hash
  #
  def attributes=(attributes)
    attributes.each do |key, value|
      self.send("#{key}=", value) if respond_to?(key.to_sym)
    end if attributes
  end

  # Get the conducted attribute methods
  #
  # @return [Hash] the conducted attributes values
  #
  def attributes
    self.class.conducted_attributes.inject({}) do |attributes, name|
      attributes[name.to_s] = send(name)
      attributes
    end
  end

  # Tests if all of the records have been persisted.
  #
  # @return [true, false] the persistence status
  #
  def new_record?
    models.all? { |m| m.new_record? }
  end

  # Tests if the associated models have errors. The errors
  # can be accessed afterwards through {#errors}.
  #
  # @return [true, false] the error status
  #
  def valid?
    models.inject(true) do |result, model|
      valid = model.valid?

      model.errors.each do |field, value|
        errors.add(field, value)
      end

      result && valid
    end
  end

  # Returns the errors of the conductor. The errors
  # are populated after a call to {#save}, {#valid?} or {.create}.
  #
  # @return [Hash] the error hash
  #
  def errors
    @errors ||= ActiveModel::Errors.new(self)
  end

  # The models that the conductor holds.
  #
  # @return [Array] the array with the conducted models
  #
  def models
    []
  end

  # Saves the associated models.
  #
  # @return [true, false] the saved status
  #
  def save
    models.each { |model| return false unless model.save } if valid?
  end

  # Create and persist a new conductor in one step.
  #
  # @example Create and yield a conductor
  #   registration = Registration.create(params[:registration]) do |conductor|
  #     conductor.user.is_admin = true
  #   end
  #
  # @param attributes [Hash] the attributes hash to initialize the conductor
  # @param block [Proc] An optional proc that yields to the created conductor
  # @return [ActiveConductor] the created conductor
  #
  def self.create(attributes)
    object = new(attributes)
    yield(object) if block_given?
    object.save
    object
  end

  # ActiveModel compatibility method that always
  # return false since a conductor cannot be
  # destroyed (See {#persisted?}).
  #
  # @return [false] always false
  #
  def destroyed?
    false
  end

  # ActiveModel compatibility method that always
  # return false since a conductor will never be
  # persisted.
  #
  # @return [false] always false
  #
  def persisted?
    false
  end

end
