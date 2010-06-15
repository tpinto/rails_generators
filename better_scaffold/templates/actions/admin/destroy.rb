  def destroy
    @<%= singular_name %> = <%= class_name %>.find(params[:id])
    @<%= singular_name %>.destroy
    flash[:notice] = "Successfully destroyed <%= name.underscore.humanize.downcase %>."
    redirect_to admin_<%= plural_name %>_path
  end
