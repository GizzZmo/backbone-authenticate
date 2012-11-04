hyperbone.serviceTypes.HALServiceType = class HALServiceType extends hyperbone.serviceTypes.ServiceType
  discoverResources: (apiRoot) =>
    for resourceName of apiRoot._links
      resource = apiRoot._links[resourceName]

      if resourceName is 'self'
        continue

      modelName = hyperbone.util.naturalModelName resourceName
      collectionName = hyperbone.util.naturalCollectionName resourceName

      model = hyperbone.Model.factory @bone, resource.href
      collection = hyperbone.Collection.factory @bone, model, resource.href

      @bone.models[modelName] = model
      @bone.collections[collectionName] = collection
      @bone.trigger 'discovered'

  url: (originalURL) ->
    indexOfParams = originalURL.indexOf '?'

    if indexOfParams > -1
      url = originalURL.slice 0, indexOfParams
      paramsLength = originalURL.length - url.length

      params = originalURL.slice indexOfParams + 1, indexOfParams + paramsLength
    else
      url = originalURL
      params = ''

    if @bone.registry.communicationType == 'jsonp'
      if params.length > 0
        params += '&'

      params += 'format=json-p&callback=?'
 
    if params.length > 0
      url = url + '?' + params

    url

  request: (url, options) =>
    if @bone.registry.communicationType == 'jsonp'
      options.data = options.data or {}
      options.data.format = 'json-p'

    super url, options

  parseModel: (response) ->
    response

  parseCollection: (response) ->
    response

