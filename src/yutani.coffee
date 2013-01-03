# TODO: Clean this up.
hyperbone.serviceTypes.HALServiceType = class HALServiceType extends hyperbone.serviceTypes.ServiceType
  defaultInputTypes:
    'boolean': 'Checkbox'

  relationships:
    many: Backbone.HasMany
    one: Backbone.HasOne

  discoverResources: (apiRoot) =>
    @request @bone.registry.root,
      type: 'OPTIONS'
      success: (response) =>
        @schema = response.schema

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

        @parseSchema()

        @bone.trigger 'discovered'

  createRelation: (field, name) =>
    # If this isn't true then the API is using a relationship that hasn't been implemented. :(
    if field.relationship in _.keys @relationships
      relation =
        type: @relationships[field.relationship]
        key: name 
        relatedModel: @bone.models[hyperbone.util.naturalModelName field.resource]
        relatedCollection: @bone.collections[hyperbone.util.naturalCollectionName field.resource]
        reverseRelation:
          key: field.key or 'id'

      return relation

  parseSchema: =>
    for resourceName of @schema
      resource = @schema[resourceName]

      if resource.fields?
        modelName = hyperbone.util.naturalModelName resourceName

        relatedModel = @bone.models[modelName]
        relatedModel.prototype.schema = {}

        for fieldName of resource.fields
          field = resource.fields[fieldName]

          if field.type == 'relation'
            # In an ideal world, createRelation would actually be a new "Relation" object.
            relation = @createRelation field, fieldName

            # Append the new relation to our model
            relatedModel.prototype.relations.push relation

            # TODO: Recursive forms for relations?

          else
            if fieldName != 'id'
              relatedModel.prototype.schema[fieldName] =
                type: @defaultInputTypes[field.type] or 'Text'

    for model in @bone.models
      model.setup()

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

  getFormFromModel: (model) ->


  parseModel: (response, model) =>
    ### Performs any special parsing for models for this service.

    When a response is received in relation to this model, this will be called to do
    any service-specific parsing

    ###

  parseCollection: (response, collection) =>
    keys = _.keys response._embedded
 
    if keys.length > 0
      response._embedded[keys[0]]
    else
      []

