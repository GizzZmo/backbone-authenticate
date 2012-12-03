hyperbone.serviceTypes.HALServiceType = class HALServiceType extends hyperbone.serviceTypes.ServiceType
  discoverResources: (apiRoot) =>
    for resourceName of apiRoot._links
      resource = apiRoot._links[resourceName]

      if resourceName is 'self'
        continue

      modelName = hyperbone.util.naturalModelName resourceName
      collectionName = hyperbone.util.naturalCollectionName resourceName

      model = hyperbone.Model.factory @bone, modelName, resource.href
      collection = hyperbone.Collection.factory @bone, collectionName, model, resource.href

      @bone.models[modelName] = model
      @bone.collections[collectionName] = collection

    @request @bone.registry.root,
      type: 'OPTIONS'
      success: (response) =>
        @parseSchema response.schema

  parseSchema: (schema) =>
    @schema = schema

    @bone.trigger 'discovered'

  url: (originalURL) =>
    indexOfParams = originalURL.indexOf '?'

    if indexOfParams > -1
      url = originalURL.slice 0, indexOfParams
      paramsLength = originalURL.length - url.length

      params = originalURL.slice indexOfParams + 1, indexOfParams + paramsLength
    else
      url = originalURL
      params = ''
 
    if params.length > 0
      url = url + '?' + params

    if (url.lastIndexOf '/') != (url.length-1)
      url = url + '/'

    url

  request: (url, options) =>
    if @bone.registry.communicationType == 'cors'
      options.dataType = 'json'
      options.crossDomain = true

    super url, options

  parseModel: (response, model) =>
    model.meta = model.meta or {}

    result = {}
    attributes = _.keys response

    _.each attributes, (attributeName) ->
      if attributeName is '_links' or attributeName is '_embedded'
        # TODO: Add proper support for relations.
        model.meta[attributeName.slice 1] = response[attributeName]

      else
        result[attributeName] = response[attributeName]

    result

  parseCollection: (response, collection) =>
    keys = _.keys response._embedded
 
    if keys.length > 0
      response._embedded[keys[0]]
    else
      []

