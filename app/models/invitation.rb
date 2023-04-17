class Invitation < ApplicationRecord
  belongs_to :to_user, class_name: 'User', foreign_key: 'to_id', inverse_of: false
  belongs_to :from_user, class_name: 'User', foreign_key: 'from_id', inverse_of: false
  belongs_to :assignment, class_name: 'Assignment', foreign_key:   'assignment_id'
  validates :reply_status, presence: true, length: { maximum: 1 }
  validates_inclusion_of :reply_status, in: %w[W A R], allow_nil: false
  validate :to_from_cant_be_same

  # validate if the to_id and from_id are same
  def to_from_cant_be_same
    if self.from_id == self.to_id
      errors.add(:from_id, "to and from users should be different")
    end
  end

  # Return a new invitation
  # params = :assignment_id, :to_id, :from_id, :reply_status
  def invitation_factory(params);
    invitation = Invitation.new
    invitation.assignment_id = params[:assignment_id]
    invitation.to_user_id = params[:to_id]
    invitation.from_user_id = params[:from_id]
    invitation.reply_status = params[:reply_status] || "W"
    invitation
  end

  # send invite email
  def send_invite_email;
    InvitationMailer.invite_email(self).deliver_now
  end

  # Remove all invites sent by a user for an assignment.
  def self.remove_users_sent_invites_for_assignment(user_id, assignment_id);
    Invitation.where(from_user_id: user_id, assignment_id: assignment_id).destroy_all
  end

  # After a users accepts an invite, the teams_users table needs to be updated.
  # NOTE: Depends on TeamUser model, which is not implemented yet.
  def self.update_users_topic_after_invite_accept(inviter_user_id, invited_user_id, assignment_id);
    team = Team.find_by(assignment_id: assignment_id)
    return unless team

    team.add_user(invited_user_id)
    team.remove_user(inviter_user_id)
  end

  # This method handles all that needs to be done upon a user accepting an invitation.
  # First the users previous team is deleted if they were the only member of that
  # team and topics that the old team signed up for will be deleted.
  # Then invites the user that accepted the invite sent will be removed.
  # Last the users team entry will be added to the TeamsUser table and their assigned topic is updated
  def self.accept_invitation(invite_id, logged_in_user);
    team = Team.find_by(assignment_id: assignment_id)
    return unless team

    team.add_user(invited_user_id)
    team.remove_user(inviter_user_id)
  end

  # This method handles all that needs to be done upon an user decline an invitation.
  def self.decline_invitation(invite_id, logged_in_user);
    invite = Invitation.find_by(id: invite_id)
    if invite && invite.to_user == logged_in_user
      invite.reply_status = "R"
      invite.save
    end
  end

  # This method handles all that need to be done upon an invitation retraction.
  def self.retract_invitation(invite_id, logged_in_user);
    invite = Invitation.find_by(id: invite_id)
    if invite && invite.from_user == logged_in_user
      invite.destroy
    end
  end

  # check if the user is invited
  def self.invited?(invitee_user_id, invited_user_id, assignment_id);
    Invitation.where(to_user_id: invitee_user_id, from_user_id: invited_user_id, assignment_id: assignment_id).exists?
  end

  # This will override the default as_json method in the ApplicationRecord class and specify
  def as_json(options = {});
    super(options.merge({
      except: [:created_at, :updated_at],
      include: {
        assignment: { only: [:id, :name] },
        from_user: { only: [:id, :name] },
        to_user: { only: [:id, :name] },
        team: { only: [:id, :name] }
      }
    }))
  end

  def set_defaults;
    self.reply_status ||= "W"
  end

end
