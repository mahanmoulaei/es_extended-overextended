---@alias gradeKey string starts from 0 (must be string)

---@class xGradeNew
---@field name string grade name
---@field label string grade label
---@field salary number grade salary
---@field skin_male table grade male skin
---@field skin_female table grade female skin

---@class xJobNew
---@field name string job name
---@field label string job label
---@field whitelisted boolean | 1 | 0 job whitelisted state
---@field grades table<gradeKey, xGradeNew>

---Adds a job or a table of jobs on runtime
---@param jobObject xJobNew | xJobNew[]
---@return boolean
---@return string
function ESX.AddJob(jobObject)
    if type(jobObject) ~= "table" then return false, "invalid_job_object_type" end

    local jobsTable, queries = {}, {}
    local currentJobs = ESX.GetJobs()

    if jobObject.name then
        jobsTable[1] = {
            name = ((jobObject.name and type(jobObject.name) == "string") and jobObject.name) or -1,
            label = ((jobObject.label and type(jobObject.label) == "string") and jobObject.label) or -1,
            whitelisted = ((jobObject.whitelisted ~= nil and (type(jobObject.whitelisted) == "number" or type(jobObject.whitelisted) == "boolean")) and jobObject.whitelisted) or jobObject.whitelisted == nil and -1,
            grades = ((jobObject.grades and type(jobObject.grades) == "table") and jobObject.grades) or -1,
        }
    else
        for index, jobObj in pairs(jobObject) do
            jobsTable[index] = {
                name = ((jobObj.name and type(jobObj.name) == "string") and jobObj.name) or -1,
                label = ((jobObj.label and type(jobObj.label) == "string") and jobObj.label) or -1,
                whitelisted = ((jobObj.whitelisted ~= nil and (type(jobObj.whitelisted) == "number" or type(jobObj.whitelisted) == "boolean")) and jobObj.whitelisted) or jobObj.whitelisted == nil and -1,
                grades = ((jobObj.grades and type(jobObj.grades) == "table") and jobObj.grades) or -1,
            }
        end
    end

    if not #jobsTable or #jobsTable < 1 then return false, "no_job_object_received" end

    for index, jobObj in pairs(jobsTable) do
        for key, value in pairs(jobObj) do
            if value == -1 then return false, ("invalid_job_%s_parameter"):format(key) end

            if key == "name" and currentJobs[value] then
                return false, "job_already_exists"
            elseif key == "grades" then
                if type(value) ~= "table" or not next(value) then return false, "invalid_job_grades_object" end

                for gradeKey, gradeObject in pairs(value) do
                    local gradeKeyToNumber = tonumber(gradeKey)

                    if type(gradeKey) ~= "string" and (gradeKeyToNumber and type(gradeKeyToNumber) ~= "number") then return false, "invalid_job_grade_key" end

                    if type(gradeObject) ~= "table" then return false, "invalid_job_grade_object" end

                    local gradeObj = {
                        grade = gradeKeyToNumber or -1,
                        name = ((gradeObject.name and type(gradeObject.name) == "string") and gradeObject.name) or -1,
                        label = ((gradeObject.label and type(gradeObject.label) == "string") and gradeObject.label) or -1,
                        salary = ((gradeObject.salary and type(gradeObject.salary) == "number") and gradeObject.salary) or -1,
                        skin_male = ((gradeObject.skin_male and type(gradeObject.skin_male) == "table") and (next(gradeObject.skin_male) and json.encode(gradeObject.skin_male) or "{}")) or -1,
                        skin_female = ((gradeObject.skin_female and type(gradeObject.skin_female) == "table") and (next(gradeObject.skin_female) and json.encode(gradeObject.skin_female) or "{}")) or -1,
                    }

                    for key2, value2 in pairs(gradeObj) do
                        if value2 == -1 then
                            return false, ("invalid_grade_%s_%s_parameter"):format(gradeKey, key2)
                        end
                    end

                    queries[#queries + 1] = {
                        query = "INSERT INTO `job_grades` SET `job_name` = ?, `grade` = ?, `name` = ?, `label` = ?, `salary` = ?, `skin_male` = ?, `skin_female` = ?",
                        values = { jobsTable[index].name, gradeObj.grade, gradeObj.name, gradeObj.label, gradeObj.salary, gradeObj.skin_male, gradeObj.skin_female }
                    }
                end
            end
        end

        queries[#queries + 1] = {
            query = "INSERT INTO `jobs` SET `name` = ?, `label` = ?, `whitelisted` = ?",
            values = { jobsTable[index].name, jobsTable[index].label, jobsTable[index].whitelisted }
        }
    end

    if not MySQL.transaction.await(queries) then return false, "error_in_executing_queries" end

    for index in pairs(jobsTable) do
        print(("[^2INFO^7] Job ^5'%s'^7 (%s) has been added"):format(jobsTable[index].label, jobsTable[index].name))
    end

    ESX.RefreshJobs()

    return true, "job_added_successfully"
end

---@class xGradeUpdate
---@field name? string grade name
---@field label? string grade label
---@field salary? number grade salary
---@field skin_male? table grade male skin
---@field skin_female? table grade female skin

---@class xJobUpdate
---@field name string job name
---@field label? string job label
---@field whitelisted? boolean | 1 | 0 job whitelisted state
---@field grades? table<gradeKey, xGradeUpdate>

---Update a job or a table of jobs on runtime
---@param jobObject xJobUpdate | xJobUpdate[]
---@return boolean
---@return string
function ESX.UpdateJob(jobObject)
    if type(jobObject) ~= "table" then return false, "invalid_job_object_type" end

    local jobsTable, queries = {}, {}
    local currentJobs = ESX.GetJobs()

    if jobObject.name then
        if not currentJobs[jobObject.name] then return false, ("job_%s_does_not_exist"):format(jobObject.name) end

        jobsTable[1] = {
            name = ((jobObject.name and type(jobObject.name) == "string") and jobObject.name) or -1,
            label = ((jobObject.label and type(jobObject.label) == "string") and jobObject.label) or currentJobs[jobObject.name].label or -1,
            whitelisted = ((jobObject.whitelisted ~= nil and (type(jobObject.whitelisted) == "number" or type(jobObject.whitelisted) == "boolean")) and jobObject.whitelisted) or
                jobObject.whitelisted == nil and (currentJobs[jobObject.name].whitelisted or currentJobs[jobObject.name].whitelisted == nil and -1),
            grades = ((jobObject.grades and type(jobObject.grades) == "table") and jobObject.grades) or currentJobs[jobObject.name].grades or -1,
        }
    else
        for index, jobObj in pairs(jobObject) do
            if not currentJobs[jobObj.name] then return false, ("job_%s_does_not_exist"):format(jobObj.name) end

            jobsTable[index] = {
                name = ((jobObj.name and type(jobObj.name) == "string") and jobObj.name) or -1,
                label = ((jobObj.label and type(jobObj.label) == "string") and jobObj.label) or currentJobs[jobObj.name].label or -1,
                whitelisted = ((jobObj.whitelisted ~= nil and (type(jobObj.whitelisted) == "number" or type(jobObj.whitelisted) == "boolean")) and jobObj.whitelisted) or
                    jobObj.whitelisted == nil and (currentJobs[jobObj.name].whitelisted or currentJobs[jobObj.name].whitelisted == nil and -1),
                grades = ((jobObj.grades and type(jobObj.grades) == "table") and jobObj.grades) or currentJobs[jobObj.name].grades or -1,
            }
        end
    end

    if not #jobsTable or #jobsTable < 1 then return false, "no_job_object_received" end

    for index, jobObj in pairs(jobsTable) do
        for key, value in pairs(jobObj) do
            if value == -1 then return false, ("invalid_job_%s_parameter"):format(key) end

            if key == "grades" then
                if type(value) ~= "table" or not next(value) then return false, "invalid_job_grades_object" end

                for gradeKey, gradeObject in pairs(value) do
                    local gradeKeyToNumber = tonumber(gradeKey)

                    if type(gradeKey) ~= "string" and (gradeKeyToNumber and type(gradeKeyToNumber) ~= "number") then return false, "invalid_job_grade_key" end

                    if type(gradeObject) ~= "table" then return false, "invalid_job_grade_object" end

                    local currentJobGradeObject = currentJobs[jobsTable[index].name].grades[gradeKey]
                    local gradeObj = {
                        grade = gradeKeyToNumber or -1,
                        name = ((gradeObject.name and type(gradeObject.name) == "string") and gradeObject.name) or currentJobGradeObject.name or -1,
                        label = ((gradeObject.label and type(gradeObject.label) == "string") and gradeObject.label) or currentJobGradeObject.label or -1,
                        salary = ((gradeObject.salary and type(gradeObject.salary) == "number") and gradeObject.salary) or currentJobGradeObject.salary or -1,
                        skin_male = ((gradeObject.skin_male and type(gradeObject.skin_male) == "table") and (next(gradeObject.skin_male) and json.encode(gradeObject.skin_male) or "{}")) or currentJobGradeObject.skin_male or -1,
                        skin_female = ((gradeObject.skin_female and type(gradeObject.skin_female) == "table") and (next(gradeObject.skin_female) and json.encode(gradeObject.skin_female) or "{}")) or currentJobGradeObject.skin_female or -1,
                    }

                    for key2, value2 in pairs(gradeObj) do
                        if value2 == -1 then return false, ("invalid_grade_%s_%s_parameter"):format(gradeKey, key2) end
                    end

                    queries[#queries + 1] = {
                        query = "DELETE FROM `job_grades` WHERE `job_name` = ? AND `grade` = ?",
                        values = { jobsTable[index].name, gradeObj.grade }
                    }

                    queries[#queries + 1] = {
                        query = "INSERT INTO `job_grades` SET `job_name` = ?, `grade` = ?, `name` = ?, `label` = ?, `salary` = ?, `skin_male` = ?, `skin_female` = ?",
                        values = { jobsTable[index].name, gradeObj.grade, gradeObj.name, gradeObj.label, gradeObj.salary, gradeObj.skin_male, gradeObj.skin_female }
                    }
                end
            end
        end

        queries[#queries + 1] = {
            query = "REPLACE INTO `jobs` SET `name` = ?, `label` = ?, `whitelisted` = ?",
            values = { jobsTable[index].name, jobsTable[index].label, jobsTable[index].whitelisted }
        }
    end

    if not MySQL.transaction.await(queries) then return false, "error_in_executing_queries" end

    for index in pairs(jobsTable) do
        print(("[^2INFO^7] Job ^5'%s'^7 (%s) has been updated"):format(jobsTable[index].label, jobsTable[index].name))
    end

    ESX.RefreshJobs()

    return true, "job_updated_successfully"
end

---@class xJobRemove
---@field name string job name

---Removes a job or a table of job on runtime
---@param jobObject xJobRemove | xJobRemove[]
---@return boolean
---@return string
function ESX.RemoveJob(jobObject)
    if type(jobObject) ~= "table" then return false, "invalid_job_object_type" end

    local jobsTable, queries = {}, {}
    local currentJobs = ESX.GetJobs()

    if jobObject.name then
        jobsTable[1] = {
            name = ((jobObject.name and type(jobObject.name) == "string") and jobObject.name) or -1
        }
    else
        for index, jobObj in pairs(jobObject) do
            jobsTable[index] = {
                name = ((jobObj.name and type(jobObj.name) == "string") and jobObj.name) or -1
            }
        end
    end

    if not #jobsTable or #jobsTable < 1 then return false, "no_job_object_received" end

    for index, jobObj in pairs(jobsTable) do
        for key, value in pairs(jobObj) do
            if value == -1 then return false, ("invalid_job_%s_parameter"):format(key) end

            if key == "name" then
                if not currentJobs[value] then return false, ("job_%s_does_not_exist"):format(value) end

                jobsTable[index].label = currentJobs[value].label
            end
        end

        queries[#queries + 1] = {
            query = "DELETE FROM `jobs` WHERE `name` = ?", values = { jobsTable[index].name }
        }

        queries[#queries + 1] = {
            query = "DELETE FROM `job_grades` WHERE `job_name` = ?", values = { jobsTable[index].name }
        }
    end

    if not MySQL.transaction.await(queries) then return false, "error_in_executing_queries" end

    for index in pairs(jobsTable) do
        print(("[^2INFO^7] Job ^5'%s'^7 (%s) has been removed"):format(jobsTable[index].label, jobsTable[index].name))
    end

    ESX.RefreshJobs()

    return true, "job_removed_successfully"
end

---Refreshes/loads the job table from database
function ESX.RefreshJobs()
    local Jobs = {}
    local jobs = MySQL.query.await("SELECT * FROM jobs")

    for _, v in ipairs(jobs) do
        Jobs[v.name] = v
        Jobs[v.name].grades = {}
    end

    local jobGrades = MySQL.query.await("SELECT * FROM job_grades")

    for _, v in ipairs(jobGrades) do
        if Jobs[v.job_name] then
            Jobs[v.job_name].grades[tostring(v.grade)] = v
        else
            print(("[^3WARNING^7] Ignoring job grades for ^5'%s'^0 due to missing job"):format(v.job_name))
        end
    end

    for _, v in pairs(Jobs) do
        if ESX.Table.SizeOf(v.grades) == 0 then
            Jobs[v.name] = nil
            print(("[^3WARNING^7] Ignoring job ^5'%s'^0 due to no job grades found"):format(v.name))
        end
    end

    if not next(Jobs) then
        -- fallback data, if no job exist
        ESX.Jobs = {
            ["unemployed"] = {
                name = "unemployed",
                label = "Unemployed",
                whitelisted = false,
                default_duty = false,
                grades = { ["0"] = { job_name = "unemployed", grade = 0, name = "unemployed", label = "Unemployed", salary = 200, skin_male = {}, skin_female = {} } }
            }
        }
    else
        ESX.Jobs = Jobs
    end

    Core.RefreshPlayersJob()
end

---Checks if a job with the specified name and grade exist
---@param jobName string
---@param jobGrade integer | string
---@return boolean
function ESX.DoesJobExist(jobName, jobGrade)
    jobGrade = tostring(jobGrade)

    if jobName and jobGrade then
        if ESX.Jobs[jobName] and ESX.Jobs[jobName].grades[jobGrade] then
            return true
        end
    end

    return false
end

function Core.RefreshPlayersJob()
    for _, xPlayer in pairs(ESX.Players) do
        local doesJobExist = ESX.DoesJobExist(xPlayer.job.name, xPlayer.job.grade)
        xPlayer.setJob(not doesJobExist and "unemployed" or xPlayer.job.name, not doesJobExist and 0 or xPlayer.job.grade)
    end
end
