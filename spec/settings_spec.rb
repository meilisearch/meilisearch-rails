require 'spec_helper'

describe MeiliSearch::Rails::IndexSettings do
  describe 'settings change detection' do
    let(:record) { Color.create name: 'dark-blue', short_name: 'blue' }

    context 'without changing settings' do
      it 'does not call update settings' do
        allow(Color.index).to receive(:update_settings).and_call_original

        record.ms_index!

        expect(Color.index).not_to have_received(:update_settings)
      end
    end

    context 'when settings have been changed' do
      it 'makes a request to update settings' do
        idx = Color.index
        task = idx.update_settings(
          filterable_attributes: ['none']
        )
        idx.wait_for_task task['taskUid']

        allow(idx).to receive(:update_settings).and_call_original

        record.ms_index!

        expect(Color.index).to have_received(:update_settings).once
      end
    end
  end
end
