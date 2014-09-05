class SourcesController < InheritedResources::Base
  def create
    @source = Source.new(params[:source])
    if @source.save
      flash[:notice] = "Source was successfully created."
      redirect_to sources_path
    else
      render "new"
    end
  end

  def update
    @source = Source.find(params[:id])
    if @source.update_attributes(params[:source])
      flash[:notice] = "Source was successfully updated."
      redirect_to sources_path
    else
      render "edit"
    end
  end
end
