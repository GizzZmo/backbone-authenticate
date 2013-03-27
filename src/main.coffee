### Backbone.Authenticator

Provides OAuth2 client support to Backbone applications.

###

# TODO: Remove dependency on jQuery.deparam, which can be found here until then:
# https://gist.github.com/raw/1025817/bd35871da67be0073fffc37414e3e18e627b0d22/jquery.ba-deparam.js

# Create references to depenencies in the local scope

if window?
  jQuery = window.jQuery

  Backbone = window.Backbone or {}
  _ = window._

else
  jQuery = require 'jquery'

  Backbone = require 'backbone'
  _ = require 'underscore'


$ = jQuery

# Creates our Authenticator namespace if it doesn't already exist
Backbone.Authenticate = Backbone.Authenticate or {}

Backbone.Authenticate.defaultRegistry = defaultRegistry =
    popup: true
    responseType: 'code'
    grantType: 'authorization_code'

    paramNames:
      client_id: 'client_id'
      client_secret: 'client_secret'
      redirect_uri: 'redirect_uri'
      scope: 'scope'
      state: 'state'
      response_type: 'response_type'
      grant_type: 'grant_type'
      code: 'code'

Backbone.Authenticate.Authenticator = class Authenticator
  """ Core object which can be used to perform all authentication-related tasks.

  """

  # When we have a token, it will be stored here.
  token: null

  # When does this ticket expire?
  expires: null

  # When we have a refresh token, it is stored here.
  refershToken: null

  # The persmissions that have been given to us stored as a list
  scope: []

  # When we've received a token, all response parameters will be available here.
  response: null

  # During the auth process, this is the window where authentication is occuring.
  dialog: null

  # Whether or not we are currently authenticated
  authenticated: false

  requiredOptions: [
    'authenticateURI',
    'redirectURI',
    'clientID',
  ]

  responseHandlerPrefix: 'handle'

  registry: defaultRegistry

  constructor: (options) ->
    _.extend @, Backbone.Events

    options = options or {}
    @parseOptions options

  parseOptions: (options) ->
    _.extend @registry, options

    for name in @requiredOptions

      # If someone creates an inherited class that defines these, we're okay.
      if @registry[name] then continue

      # Throws an error if a required option hasn't been provided.
      @registry[name]? or

        throw new Error "An #{name} option must be provided to your
                         Authenticator."

    if @registry.responseType? and !@[@methodNameForResponseType @registry.responseType]?
        throw new Error "#{@registry.responseType} is not a supported response
                         type for this authenticator."

    if @registry.responseType == 'code'

      if !@registry.authorizeURI?
        throw new Error 'Code-based authentication requires authorizeURI
                         is provided to your authenticator.'

      if !@registry.grantType?
        throw new Error 'The grantType option must be provided when using
                         code-based authentication.'

    # Scopes are supposed to be passed as lists, but strings are supported.
    if @registry.scope? and not @registry.scope.join?
      @registry.scope = _.map @registry.scope.split ','

  authenticateURI: ->
    ### Builds the URL to our initial OAuth endpoint.                      ###

    params = {}

    params[@registry.paramNames.client_id] = @registry.clientID
    params[@registry.paramNames.redirect_uri] = @registry.redirectURI
    params[@registry.paramNames.response_type] = @registry.responseType

    # Add state and scope as necessary
    if @registry.state? then params[@registry.paramNames.state] = @registry.state
    if @registry.scope? then params[@registry.paramNames.scope] = @registry.scope.join ','

    paramNames = _.keys params

    # Convert our params object to a list of strings formatted with '='
    paramString = _.map paramNames, (name) ->
      if params[name]? and params[name] != ''
        return name + '=' + params[name]
      else
        return name

    paramString = paramString.join '&'

    @registry.authenticateURI + '?' + paramString

  authorizationData: (code) ->
    ### Builds the URL for our authorization endpoint for getting tickets. ###

    params = {}

    params[@registry.paramNames.client_id] = @registry.clientID
    params[@registry.paramNames.grant_type] = @registry.grantType
    params[@registry.paramNames.redirect_uri] = @registry.redirectURI
    params[@registry.paramNames.code] = code

    if @registry.clientSecret?
      params[@registry.paramNames.client_secret] = @registry.clientSecret

    return params

  methodNameForResponseType: (typeName) ->
    ### Receives a response type and converts it into it's handler's method name.

    ###

    formattedTypeName = typeName[0].toUpperCase() + typeName[1..].toLowerCase()

    return @responseHandlerPrefix + formattedTypeName

  begin: =>
    ### Initiates the user authentication process.

    Initiates the user authentication process. Optionally, you can provide any
    registry options that this process should override.

    ###

    authenticateURI = @authenticateURI()

    if @registry.popup is true
      @dialog = window.open authenticateURI

    else
      # TODO: Test whether or not this even works
      window.location = authenticateURI

  processResponse: =>
    ### After authentication, this function finishes the authentication process.

    ###

    parameters = jQuery.deparam window.location.search[1..]

    if !parameters.error?
      # Get a reference to our function that handles this type of response
      handlerName = @methodNameForResponseType @registry.responseType
      handler = @[handlerName]

      # Call our handler method providing parameters object
      handler parameters

    else
      @trigger 'error', parameters.error

    if parameters.state?
      @trigger 'state:change', parameters.state

  handleCode: (parameters) =>
    ### Response handler for "code" response type.

    ####

    if !parameters.code?
      throw new Error 'No code parameter was provided by the provider.'

    jQuery.ajax
      type: 'POST'
      url: @registry.authorizeURI
      data: @authorizationData parameters.code

      success: (response) =>
        @processToken JSON.parse response

  handleToken: (parameters) =>
    ### Response handler for "token" response type.

    ###

    if !parameters.token?
      throw new Error 'No token parameter was provided by the OAuth provider.'

    @processToken parameters.token

  processToken: (response) =>
    authenticated = @isAuthenticated()

    window.response = response

    @token = response.access_token
    @refreshToken = response.refresh_token
    @expires = response.expires_in
    @scope = response.scope.split ','

    if @refreshToken != null then setTimeout @refreshAuthorization, @expires * 1000

    @trigger 'token:changed'

    # The "authenticated" event is a special event that only is triggered when
    # a user has manually authenticated with the user.
    if not authenticated then @trigger 'authenticated'

  refreshAuthorization: =>
    # TODO: Refreshing of authorization codes.

  isAuthenticated: => @token != null

