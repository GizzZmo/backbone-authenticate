hyperbone.serviceTypes.HALServiceType = class HALServiceType
  constructor: (@bone) ->

  discoverResources: (apiRoot) =>
    for resourceName of apiRoot._links
      resource = apiRoot._links[resourceName]

      if resourceName is 'self'
        continue

      modelName = hyperbone.util.naturalModelName resourceName

      @bone.models[modelName] = hyperbone.Model.factory resource.href, @
      @bone.trigger 'discovered'


