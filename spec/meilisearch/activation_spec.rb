describe MeiliSearch::Rails do
  it 'is active by default' do
    expect(MeiliSearch::Rails).to be_active
  end

  describe '#deactivate!' do
    context 'without block' do
      before { MeiliSearch::Rails.deactivate! }

      after { MeiliSearch::Rails.activate! }

      it 'deactivates the requests until activate!-ed' do
        expect(MeiliSearch::Rails).not_to be_active
      end

      it 'responds with a black hole' do
        expect(MeiliSearch::Rails.client.foo.bar.now.nil.item.issue).to be_nil
      end
    end

    context 'with a block' do
      it 'disables only around call' do
        MeiliSearch::Rails.deactivate! do
          expect(MeiliSearch::Rails).not_to be_active
        end

        expect(MeiliSearch::Rails).to be_active
      end

      it 'works in multi-threaded environments' do
        Threads.new(5, log: $stdout).assert(20) do |_i, _r|
          MeiliSearch::Rails.deactivate! do
            expect(MeiliSearch::Rails).not_to be_active
          end

          expect(MeiliSearch::Rails).to be_active
        end
      end
    end
  end
end
