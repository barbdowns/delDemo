OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE #TODO, fix hackish ssl certification workaround
require 'json'
require 'csv'

class GetQuestionnaires

    def self.getOldQuestionnaire
        questionnaires = CSV.read("storage/Data_Elements.csv")
        keys = questionnaires[0]
        questionnaires = questionnaires.drop(1)
        questionnaires.map{ |values| Hash[keys.zip(values)] }
    end

    def self.setClientConnection
        @url = "https://impact-fhir.mitre.org/r4/"
        @client = FHIR::Client.new(@url)
        FHIR::Model.client = @client
    end

    def self.getAllQuestionnaires
        setClientConnection()
        initialQuestionnaires = @client.read_feed(FHIR::Questionnaire)
        json = initialQuestionnaires.response.values[2]
        @questionnaireHash = JSON.parse(json)

        hashes = [].append(@questionnaireHash)
        i = 0
        while true
            shouldBreak = true
            nextLink = ''
            break if hashes[i]["link"].nil?
            hashes[i]["link"].each do |link|
                if !link["url"].nil? && link["relation"].eql?("next") && !link["url"].empty?
                    shouldBreak = false
                    nextLink = link["url"] + "?_format=json"
                end
            end
            break if shouldBreak
            i += 1
            nextQuestionnaires = @client.raw_read_url(nextLink)
            nextJSON = nextQuestionnaires.response.values[2]
            hashes.append(JSON.parse(nextJSON))
        end

        @questionnaireHash = combineQuestionnaires(hashes)
    end

    def self.combineQuestionnaires(hashes)
        finalEntry = Array.new
        hashes.each do |hash|
            return nil if hash["entry"].nil?
            finalEntry.append(hash["entry"])
        end
        hashes[0]["entry"] = finalEntry.flatten
        hashes[0]
    end

    def self.getQuestionnaire(version)
        if @questionnaireHash.nil?
            getAllQuestionnaires()
        end
        @questionnaireHash["entry"].each do |questionnaire|
            if questionnaire["resource"]["id"].eql?(version)
                return questionnaire
            end
        end 
        return nil
    end
end