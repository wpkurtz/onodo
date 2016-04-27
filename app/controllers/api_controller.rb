class ApiController < ApplicationController

  # Get all Nodes (for a visualization)
  # GET /api/visualizations/:visualization_id/nodes
  def nodes
    dataset = Dataset.find_by(visualization_id: params[:visualization_id])
    render json: Node.where(dataset_id: dataset.id).order(:name)
  end

  # Get uniques & non-blank Nodes Types (for a visualization)
  # GET /api/visualizations/:visualization_id/nodes/types
  def nodes_types
    dataset = Dataset.find_by(visualization_id: params[:visualization_id])
    render json: Node.where(dataset_id: dataset.id).select(:node_type).map(&:node_type).reject(&:blank?).uniq
  end

  # Get a Node
  # GET /api/nodes/:id
  def node
    render json: Node.find(params[:id])
  end

  # Create a new Node
  # POST /api/nodes
  def node_create
    #puts node_params
    node = Node.new(node_params)
    node.save(:validate => false)
    render json: node
  end

  # Update a Node attribute
  # PUT /api/nodes/:id
  def node_update
    Node.update(params[:id], node_params)
    render json: {}
    #TODO! Add error validation
  end

  # Delete a Node
  # DELETE /api/nodes/:id
  def node_destroy
    Node.destroy(params[:id])
    render json: {}
    #TODO! Add error validation
  end

  ###

  # Get all Relations (for a visualization)
  # GET /api/visualizations/:visualization_id/relations
  def relations
    dataset = Dataset.find_by(visualization_id: params[:visualization_id])
    @relations = Relation.where(dataset_id: dataset.id)
                         .includes(:source, :target)
                         .order("nodes.name", "targets_relations.name")
  end

  # Get uniques & non-blank Relations Types (for a visualization)
  # GET /api/visualizations/:visualization_id/relations/types
  def relations_types
    dataset = Dataset.find_by(visualization_id: params[:visualization_id])
    render json: Relation.where(dataset_id: dataset)
                        .select(:relation_type)
                        .map(&:relation_type)
                        .reject(&:blank?).uniq
  end

  # Get a Relation
  # GET /api/relations/:id
  def relation
    @relation = Relation.find(params[:id])
  end

  # Create a new Relation
  # POST /api/relations
  def relation_create
    relation = Relation.new(relation_params)
    relation.save(:validate => false)
    render json: relation
  end

  # Update a Relation attribute
  # PUT /api/relations/:id
  def relation_update
    Relation.update(params[:id], relation_params)
    render json: {}
  end

  # Delete a Relation
  # DELETE /api/relations/:id
  def relation_destroy
    Relation.destroy(params[:id])
    render json: {}
  end

  ###

  # Get a Visualization
  # GET /api/visualizations/:visualization_id/
  def visualization
    dataset = Dataset.find_by(visualization_id: params[:visualization_id])
    @dataset_id = dataset.id
    @visualization = Visualization.find(params[:visualization_id])
  end

  # Update a Visualization
  # PUT /api/visualizations/:visualization_id/
  def visualization_update
    Visualization.update(params[:visualization_id], visualization_params)
    render json: {}
  end


  private

    def node_params
      params.require(:node).permit(:name, :description, :visible, :node_type, :custom_field, :visualization_id, :dataset_id) if params[:node]
    end

    def relation_params
      params.require(:relation).permit(:source_id, :target_id, :relation_type, :direction, :from, :to, :at, :visualization_id, :dataset_id) if params[:relation]
    end

    def visualization_params
      params.require(:visualization).permit(:parameters) if params[:visualization]
    end

end
