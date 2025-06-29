###
Backbone.Authenticator

Provides OAuth2 client support to Backbone applications, with minimal dependencies and improved maintainability.
###

# Environment abstraction
if typeof window isnt "undefined"
  jQuery = window.jQuery
  Backbone = window.Backbone or {}
  _ = window._
else
  jQuery = require 'jquery'
  Backbone = require 'backbone'
  _ = require 'underscore'

$ = jQuery

# Utility: Parse query string to object (replaces jQuery.deparam)
parseQueryString = (query) ->
  params = {}
  if !query then return params
  pairs = query.replace(/^\?/, '').split('&')
  for pair in pairs when pair
    [key, value] = pair.split('=')
    key = decodeURIComponent(key)
    value = decodeURIComponent(value or '')
    params[key] = value
  params

# OAuth2 parameter names mapping (standardized)
paramNames =
  clientId: 'client_id'
  clientSecret: 'client_secret'
  redirectUri: 'redirect_uri'
  scope: 'scope'
  state: 'state'
  responseType: 'response_type'
  grantType: 'grant_type'
  code: 'code'

# Default registry (static property)
Backbone.Authenticate = Backbone.Authenticate or {}
Backbone.Authenticate.defaultRegistry =
  popup: true
  responseType: 'code'
  grantType: 'authorization_code'
  paramNames: paramNames

# Required options (static property)
Backbone.Authenticate.requiredOptions = [
  'authenticateUri'
  'redirectUri'
  'clientId'
]

###
Core object to perform all authentication-related tasks for OAuth2.
###
Backbone.Authenticate.Authenticator = class Authenticator

  # Static properties for config and required fields
  @defaultRegistry: Backbone.Authenticate.defaultRegistry
  @requiredOptions: Backbone.Authenticate.requiredOptions

  ###
  Constructor: Accepts options for configuration.
  ###
  constructor: (options = {}) ->
    _.extend @, Backbone.Events

    # Registry: deep copy of default, then override with user options
    @registry = _.extend {}, @constructor.defaultRegistry, options
    @parseOptions options

    # Auth state
    @token = null
    @expires = null
    @refreshToken = null
    @scope = []
    @response = null
    @dialog = null
    @authenticated = false

  ###
  Parse options and validate required fields.
  ###
  parseOptions: (options) ->
    reg = @registry
    # Support comma string for scope
    if reg.scope? and not Array.isArray(reg.scope)
      reg.scope = _.map reg.scope.split(','), (s) -> s.trim()
    # Validate required options
    for name in @constructor.requiredOptions
      unless reg[name]?
        throw new Error "Option '#{name}' must be provided to Authenticator."

    # Validate supported response type
    methodName = @methodNameForResponseType reg.responseType
    unless @[methodName]?
      throw new Error "'#{reg.responseType}' is not a supported response type."

    # Extra checks for code flow
    if reg.responseType is 'code'
      unless reg.authorizeUri?
        throw new Error "Option 'authorizeUri' is required for code-based authentication."
      unless reg.grantType?
        throw new Error "Option 'grantType' must be provided for code-based authentication."

  ###
  Build the OAuth authentication URL.
  ###
  authenticateUri: ->
    reg = @registry
    params = {}
    params[reg.paramNames.client_id] = reg.clientId
    params[reg.paramNames.redirect_uri] = reg.redirectUri
    params[reg.paramNames.response_type] = reg.responseType
    if reg.state? then params[reg.paramNames.state] = reg.state
    if reg.scope? then params[reg.paramNames.scope] = reg.scope.join(',')

    paramString = (k + '=' + encodeURIComponent(v) for k, v of params when v?).join('&')
    reg.authenticateUri + '?' + paramString

  ###
  Build the POST data for requesting the access token.
  ###
  authorizationData: (code) ->
    reg = @registry
    params = {}
    params[reg.paramNames.client_id] = reg.clientId
    params[reg.paramNames.grant_type] = reg.grantType
    params[reg.paramNames.redirect_uri] = reg.redirectUri
    params[reg.paramNames.code] = code
    if reg.clientSecret?
      params[reg.paramNames.client_secret] = reg.clientSecret
    params

  ###
  Get the handler method name for a response type.
  ###
  methodNameForResponseType: (typeName) ->
    prefix = 'handle'
    formatted = typeName.charAt(0).toUpperCase() + typeName.slice(1).toLowerCase()
    prefix + formatted

  ###
  Start the authentication process.
  ###
  begin: (overrideOptions = {}) =>
    _.extend @registry, overrideOptions
    url = @authenticateUri()
    if @registry.popup is true
      @dialog = window.open url
    else
      window.location.assign url

  ###
  Process OAuth response from the provider.
  ###
  processResponse: =>
    params = parseQueryString(window.location.search)
    if !params.error?
      handlerName = @methodNameForResponseType(@registry.responseType)
      handler = @[handlerName]
      handler(params)
    else
      @trigger 'error', params.error
    if params.state?
      @trigger 'state:change', params.state

  ###
  Handle "code" response type.
  Exchanges authorization code for an access token.
  ###
  handleCode: (parameters) =>
    unless parameters.code?
      throw new Error "No 'code' parameter provided by the provider."
    # Use Promises for AJAX
    $.ajax(
      type: 'POST'
      url: @registry.authorizeUri
      data: @authorizationData(parameters.code)
      success: (response) =>
        try
          data = if typeof response is 'string' then JSON.parse(response) else response
          @processToken data
        catch e
          @trigger 'error', "Failed to parse authorization response: #{e}"
      error: (xhr, status, err) =>
        @trigger 'error', "Token request failed: #{status} #{err}"
    )

  ###
  Handle "token" response type (implicit grant).
  ###
  handleToken: (parameters) =>
    unless parameters.token?
      throw new Error "No 'token' parameter provided by the OAuth provider."
    @processToken parameters.token

  ###
  Store and process received token data.
  ###
  processToken: (response) =>
    alreadyAuthenticated = @isAuthenticated()
    @token = response.access_token
    @refreshToken = response.refresh_token
    @expires = response.expires_in
    @scope = if typeof response.scope is 'string' then response.scope.split(',') else []
    if @refreshToken? and @expires?
      setTimeout @refreshAuthorization, @expires * 1000
    @trigger 'token:changed'
    @trigger 'authenticated' unless alreadyAuthenticated

  ###
  Refresh authorization (stub for future implementation).
  ###
  refreshAuthorization: =>
    # TODO: Implement refresh token logic.
    null

  ###
  Returns true if authenticated.
  ###
  isAuthenticated: => !!@token
