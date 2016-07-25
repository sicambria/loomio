angular.module('loomioApp').controller 'GroupPageController', ($rootScope, $location, $routeParams, $scope, Records, Session, MessageChannelService, AbilityService, AppConfig, LmoUrlService, PaginationService, ModalService, SubscriptionSuccessModal, GroupWelcomeModal) ->
  $rootScope.$broadcast 'currentComponent', {page: 'groupPage', key: $routeParams.key}

  $scope.$on 'joinedGroup', => @handleWelcomeModal()

  # allow for chargify reference, which comes back #{groupKey}|#{timestamp}
  $routeParams.key = $routeParams.key.split('|')[0]
  Records.groups.findOrFetchById($routeParams.key).then (group) =>
    @group = group

    if AbilityService.isLoggedIn()
      MessageChannelService.subscribeToGroup(@group)
      Records.drafts.fetchFor(@group)
      @handleSubscriptionSuccess()
      @handleWelcomeModal()

    maxDiscussions = if AbilityService.canViewPrivateContent(@group)
      @group.discussionsCount
    else
      @group.publicDiscussionsCount
    @pageWindow = PaginationService.windowFor
      current:  parseInt($location.search().from or 0)
      min:      0
      max:      maxDiscussions
      pageType: 'groupThreads'

    $rootScope.$broadcast 'viewingGroup', @group
    $rootScope.$broadcast 'setTitle', @group.fullName
    $rootScope.$broadcast 'analyticsSetGroup', @group
    $rootScope.$broadcast 'currentComponent',
      page: 'groupPage'
      key: @group.key
      links:
        canonical:   LmoUrlService.group(@group, {}, absolute: true)
        rss:         LmoUrlService.group(@group, {}, absolute: true, ext: 'xml') if !@group.privacyIsSecret()
        prev:        LmoUrlService.group(@group, from: @pageWindow.prev)         if @pageWindow.prev?
        next:        LmoUrlService.group(@group, from: @pageWindow.next)         if @pageWindow.next?

  , (error) ->
    $rootScope.$broadcast('pageError', error)

  @showDescriptionPlaceholder = ->
    !@group.description

  @canManageMembershipRequests = ->
    AbilityService.canManageMembershipRequests(@group)

  @canUploadPhotos = ->
    AbilityService.canAdministerGroup(@group)

  @openUploadCoverForm = ->
    ModalService.open CoverPhotoForm, group: => @group

  @openUploadLogoForm = ->
    ModalService.open LogoPhotoForm, group: => @group

  @handleSubscriptionSuccess = ->
    if (AppConfig.chargify or AppConfig.environment == 'development') and $location.search().chargify_success?
      @subscriptionSuccess = true
      @group.subscriptionKind = 'paid' # incase the webhook is slow
      $location.search 'chargify_success', null
      ModalService.open SubscriptionSuccessModal

  @showWelcomeModal = ->
    @group.isParent() and
    Session.user().isMemberOf(@group) and
    !@subscriptionSuccess and
    !Session.user().hasExperienced("welcomeModal", @group)

  @handleWelcomeModal = =>
    if @showWelcomeModal()
      ModalService.open GroupWelcomeModal, group: => @group
      Records.memberships.saveExperience("welcomeModal", Session.user().membershipFor(@group))

  return
