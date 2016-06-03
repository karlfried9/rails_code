class Ability
  include CanCan::Ability

  def initialize(user)

    user ||= Employee.new

    can :login unless user.login_disabled?

    venue_admin_permissions(user) if user.is_venue_admin?

    if user.is_super_admin?
      can :masquerade, Employee
      can :manage, :all
    end

    unless user.is_super_admin?
      cannot :create, Ticket
      cannot :destroy, Ticket
    end

    # Client admin can only manage their own employees
    if user.is_client_admin?

      can [:manage, :masquerade], Employee, company_id: user.company_id

      # can manage his company
      can [:read, :update], Company, id: user.company_id

      can :read, [Venue, Event]

      can [:create, :update], Venue, created_by_client: user.company_id

      # can :manage, :all
      can :read, Ticket, client_id: user.company_id, status: :released


      can :create, Inventory, client_id: user.company_id, created_by_client: true
      can [:read, :update], Inventory, client_id: user.company_id


      can :manage, InventoryRelease, client_id: user.company_id

      can :manage, ConfirmedInventoryOption, client_id: user.company_id
      can :manage, [Department, Employee], company_id: user.company_id

      #TODO proper permissions for this
      # releasedinventoryrequest#removing
      # can :manage, [ReleasedInventoryRequest, RequestAttendance], inventory: { client_id: user.company_id }
      can :manage, RequestAttendance, inventory: { client_id: user.company_id }


      can :manage, [MailTemplate, Guest], company_id: user.company_id

      can :create, MailTemplate, company_id: user.company_id, locale: :en, format: :html, handler: :liquid

      # TODO give good access rights
      can :datatable, Guest, company_id: user.company_id

      can :manage, CompanyConfig, company_id: user.company_id
    end

    # for calendar TODO give the right access
    can :calendar, Event
    can :show, Event
    can :read, EventDate

    # Should be in a block
    can :manage, [JobDescription, GuestPartner], company_id: user.company_id

    can :read, Inventory, client_id: user.company_id
    can :read, MailTemplate, company_id: user.company_id

    can :read, Employee, id: user.id

    # can :manage, ApprovalPath, owner_id: user.id
    can :read, ApprovalPath, approval_path_ownable_id: user.company_id, approval_path_ownable_type: 'Company'

    if user.department_id
      can :read, ApprovalPath, approval_path_ownable_id: user.department.self_and_ancestor_ids, approval_path_ownable_type: 'Department'
    end

    can :read, ApprovalPath, approval_path_ownable_id: user.id, approval_path_ownable_type: 'Employee'


    standard_user_permissions(user) if user.is_standard_user?

    # Owner === Approval Path
    # department_owner_permissions(user) if user.has_ownership_of_departments?

    # Gatekeeper is allocater etc

    department_gatekeeper_permissions(user) if user.department_gatekeeper_ids && !user.is_client_admin?

  end

  # # owner is for approval paths
  # def owned_department_ids(user)
  #   Department.where("owner_id = ? OR (secondary_owner_id = ? AND secondary_owner_active = true)", user.id, user.id).ids
  # end
  #
  # # Not used at the moment
  # # TODO Remove
  # def department_owner_permissions(user)
  #   can :manage, Employee, department_id: owned_department_ids(user), company_id: user.company_id
  #   # can :manage, Employee, company_id: user.company_id
  #   can :read, Department, id: owned_department_ids(user)
  #
  #   can [:read, :update], InventoryRelease, department_id: owned_department_ids(user)
  #
  #   #TODO Approval Stuff
  # end


  # the marias of the world
  def department_gatekeeper_permissions(user)
    # TODO multi-level
    gatekept_departments = Department.where(id: user.department_gatekeepers.pluck(:department_id))
    gatekept_department_ids = gatekept_departments.map(&:child_ids).flatten
    gatekept_department_ids += gatekept_departments.map(&:id)
    gatekept_department_ids.uniq!

    # can [:read, :create, :update], Guest, company_id: user.company_id



    can [:read, :create, :update], Guest, department_partitioning_id: user.department_partitioning_point_id, company_id: user.company_id

    can :create, Employee, company_id: user.company_id

    can [:read, :update], Department, id:  gatekept_department_ids
    can :create, Department, parent_id: gatekept_department_ids

    can [:read, :update], [InventoryRelease, Employee],  department_id: gatekept_department_ids

    # Lock down with a join on inventoryrelease
    # releasedinventoryrequest#removing
    # can :manage, ReleasedInventoryRequest, inventory_release: {department_id: gatekept_department_ids}

    #
    # releasedinventoryrequest#removing
    # can :manage, RequestAttendance, released_inventory_request: {inventory_release: {department_id: gatekept_department_ids}}
    can :manage, RequestAttendance, inventory_release: {department_id: gatekept_department_ids}
    # can :manage, RequestAttendance do |request_attendance|
    #   user.department_gatekeepers.pluck(:department_id).include? request_attendance.requester.department_id
    # end

  end

  def standard_user_permissions(user)
    # can :read, ReleasedInventoryRequest, client_id: user.company_id

    # TODO request attendance + bidding release
    # can :manage, RequestAttendance,
    # TODO Bidding done by department administrator / gatekeeper on behalf of BU users, approved by manager

    #
    # Gatekeeper -> BU manager -> BU gatekeeper
    #

    can :datatable, Guest, company_id: user.company_id
    can :read, Guest, company_id: user.company_id

    # for calendar TODO give the right access
    can :calendar, Event
    can :show, Event
    can :read, EventDate

    can :manage, InventoryRelease, client_id: user.company_id, department_id: user.department_id
    # can :read, InventoryRelease, client_id: user.company_id, department_id: user.department_id

    can :manage, RequestAttendance, inventory_release: {department_id: user.department_id}
  end

end
