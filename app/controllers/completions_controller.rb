class CompletionsController < ApplicationController
  before_action :set_completion, only: %i[show edit update destroy]

  # GET /completions
  def index
    @completions = Completion.all
  end

  # GET /completions/1
  def show
  end

  # GET /completions/new
  def new
    @completion = Completion.new
  end

  # GET /completions/1/edit
  def edit
  end

  # POST /completions
  def create
    @completion = Completion.new(completion_params)

    if @completion.save
      redirect_to @completion, notice: "Completion was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /completions/1
  def update
    if @completion.update(completion_params)
      redirect_to params[:return_to].presence || @completion, notice: "Completion was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /completions/1
  def destroy
    @completion.destroy!
    redirect_to completions_path, notice: "Completion was successfully destroyed.", status: :see_other
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_completion
    @completion = Completion.find(params.expect(:id))
  end

  # Only allow a list of trusted parameters through.
  def completion_params
    params.expect(completion: [ :requirement_id, :participation_id, :artifacts, :complete ])
  end
end
