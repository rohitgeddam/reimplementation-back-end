class Api::V1::InvitationsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :invite_not_found

  # GET /api/v1/invitations
  def index;
    @invitations = Invitation.all
    render json: @invitations, status: :ok
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end

  # POST /api/v1/invitations/
  def create;
    @invitation = Invitation.new(invitation_params)
    if @invitation.save
      render json: @invitation, status: :created
    else
      render json: { error: @invitation.errors.full_messages }, status: :unprocessable_entity
    end
    puts "Saving invitation"
  end

  # GET /api/v1/invitations/:id
  def show;
    @invitation = Invitation.find(params[:id])
    render json: @invitation, status: :ok
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end

  # PATCH /api/v1/invitations/:id
  def update;
    @invitation = Invitation.find(params[:id])
    if @invitation.update(invitation_params)
      render json: @invitation, status: :ok
    else
      render json: { error: @invitation.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end

  # DELETE /api/v1/invitations/:id
  def destroy;
    @invitation = Invitation.find(params[:id])
    if @invitation.destroy
      head :no_content
    else
      render json: { error: "Failed to delete the invitation" }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end

  # GET /invitations/:user_id/:assignment_id
  def list_all_invitations_for_user_assignment;
    @invitations = Invitation.where(assignee_id: params[:user_id], assignment_id: params[:assignment_id])
    render json: @invitations, status: :ok
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end

  private

  # This method will check if the invited user exists.
  def check_invited_user_before_invitation;
    @invited_user = User.find_by(email: params[:email])
    if @invited_user.nil?
      render json: { error: "User not found for email #{params[:email]}" }, status: :not_found
    elsif @invited_user.id == current_user.id
      render json: { error: "Can't self invite" }, status: :unprocessable_entity
    elsif Invitation.exists?(assignee_id: @invited_user.id, assignment_id: params[:assignment_id])
      render json: { error: "User already invited for this assignment" }, status: :unprocessable_entity
    else
      render json: { message: "User is valid for invitation" }, status: :ok
    end
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end

  # This method will check if the invited user is a participant in the assignment.
  def check_participant_before_invitation;
    @assignment = Assignment.find(params[:assignment_id])
    @invited_user = User.find_by(email: params[:email])

    if @invited_user.nil?
      render json: { error: "User not found for email #{params[:email]}" }, status: :not_found
    elsif @assignment.participants.include?(@invited_user)
      render json: { message: "User is a participant in this assignment" }, status: :ok
    else
      render json: { error: "User is not a participant in this assignment" }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end

  # This method will check if the team meets the joining requirement before sending an invite.
  # NOTE: This method depends on TeamUser and AssignmentTeam, which is not implemented yet.
  def check_team_before_invitation;
    @assignment = Assignment.find(params[:assignment_id])
    @team = Team.find(params[:team_id])

    # check if the team meets the joining requirements for the assignment
    if @assignment.joining_requirements_met?(@team)
      render json: { message: "Team meets joining requirements for this assignment" }, status: :ok
    else
      render json: { error: "Team does not meet joining requirements for this assignment" }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end

  # This method will check if the team meets the joining requirements
  # when an invitation is being accepted
  # NOTE: This method depends on AssignmentParticipant and AssignmentTeam
  # which is not implemented yet.
  def check_team_before_accept;
    @assignment = Assignment.find(params[:assignment_id])
    @invitation = Invitation.find(params[:id])
    @team = @invitation.team

    # check if the team meets the joining requirements for the assignment
    if @assignment.joining_requirements_met?(@team)
      # Add participant to the assignment
      @participant = AssignmentParticipant.create(user: @invitation.invited_user, assignment: @assignment, team: @team)

      # Remove the invitation
      @invitation.destroy

      render json: { message: "Invitation accepted, participant added to the assignment" }, status: :ok
    else
      render json: { error: "Team does not meet joining requirements for this assignment" }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end

  # only allow a list of valid invite params
  def invite_params;
    params.require(:invitation).permit(:invited_user_id, :team_id, :assignment_id)
  end

  # helper method used when invite is not found
  def invite_not_found;
    render json: { error: "Invitation not found" }, status: :not_found
  end

  private

  # only allow a list of valid params
  def invitation_params;
    params.require(:invitation).permit(:assignment_id, :to_id, :from_id, :reply_status)
  end

end
