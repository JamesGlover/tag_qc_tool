class QcDecisionsController < ApplicationController

  def find_lot_presenter
    @lot_presenter = Presenter::Lot.new(api.lot.find(params[:lot_id]))
  end


  def find_lots_for_batch
    api.search.find(Settings.searches['Find lot by batch id']).all(
        Sequencescape::Lot,
        :batch_id => params[:batch_id])
  end

  ##
  # Finds a lot for qcing on the basis of batch id
  def search
    rescue_no_results("Could not find an appropriate lot for batch #{params[:batch_id]}.") do
      lots = find_lots_for_batch
      if (lots.count > 1)
        redirect_to new_batch_qc_decision_path(params[:batch_id])
      else
        redirect_to new_lot_qc_decision_path(lots.first.uuid)
      end
    end
  end
end
