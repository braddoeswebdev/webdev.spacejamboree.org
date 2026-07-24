class WorkshopsController < ApplicationController
  before_action :set_workshop, only: %i[show edit update destroy work work_requirement review review_requirement]

  # GET /workshops
  def index
    @workshops = Workshop.all
  end

  # GET /workshops/1
  def show
  end

  # GET /workshops/1/work
  def work
    @participation = @workshop.participations.find_by!(user: Current.user)
    Requirement.find_each do |req|
      Completion.find_or_create_by!(participation: @participation, requirement: req)
    end
    @badges = Badge.includes(:requirements).all
    @completions = Completion.where(participation: @participation).index_by(&:requirement_id)
  end

  # GET /workshops/1/work/:requirement_id
  def work_requirement
    @participation = @workshop.participations.find_by!(user: Current.user)
    @requirement = Requirement.find(params.expect(:requirement_id))
    @completion = Completion.find_or_create_by!(participation: @participation, requirement: @requirement)
  end

  # GET /workshops/1/review
  def review
    @badges = Badge.includes(:requirements).all
    @completion_counts = Completion.joins(:participation)
      .where(participation: { workshop_id: @workshop.id })
      .group(:requirement_id)
      .select("requirement_id, COUNT(*) AS total, SUM(CASE WHEN complete THEN 1 ELSE 0 END) AS completed_count")
      .index_by(&:requirement_id)
  end

  # GET /workshops/1/review/:requirement_id
  def review_requirement
    @requirement = Requirement.find(params.expect(:requirement_id))
    @completions = Completion.where(requirement: @requirement)
      .joins(:participation)
      .where(participation: { workshop_id: @workshop.id })
      .includes(participation: :user)
      .order(created_at: :desc)
  end

  # GET /workshops/new
  def new
    @workshop = Workshop.new
  end

  # GET /workshops/1/edit
  def edit
  end

  # POST /workshops
  def create
    @workshop = Workshop.new(workshop_params)

    if @workshop.save
      redirect_to @workshop, notice: "Workshop was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /workshops/1
  def update
    if @workshop.update(workshop_params)
      redirect_to @workshop, notice: "Workshop was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /workshops/1
  def destroy
    @workshop.destroy!
    redirect_to workshops_path, notice: "Workshop was successfully destroyed.", status: :see_other
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_workshop
    @workshop = Workshop.find(params.expect(:id))
  end

  # Only allow a list of trusted parameters through.
  def workshop_params
    params.expect(workshop: [ :name, :instructor_id, participant_ids: [] ])
  end
end
