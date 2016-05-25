class NodesController < ApplicationController

  before_action :set_node

  # GET /nodes/:id/edit
  def edit
    # TODO!!! Check if current_user is the owner of this node
    if current_user.nil?
      #redirect_to new_user_session_path()
    end
  end

  # GET /nodes/:id/edit/description
  def edit_description
    # TODO!!! Check if current_user is the owner of this node
    if current_user.nil?
      #redirect_to new_user_session_path()
    end
    render layout: false
  end

  # GET /nodes/:id/edit/image
  def edit_image
    # TODO!!! Check if current_user is the owner of this node
    if current_user.nil?
      #redirect_to new_user_session_path()
    end
    render layout: false
  end

  # PATCH /nodes/:id/
  def update
    @node.update_attributes( node_params )
    # TODO!!! Redirect to visualization that contain the node
    #redirect_to edit_node_path( @node )
    render nothing: true, head: :ok, content_type: 'text/html'
  end

  # PATCH /nodes/:id/image
  def update_image
    @node.update_attributes( node_params )
    redirect_to edit_node_path(@node)
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_node
    @node = Node.find(params[:id])
  end

  def node_params
    params.require(:node).permit(:name, :description, :image, :image_cache, :remote_image_url, :remove_image, :custom_fields)
  end
end
