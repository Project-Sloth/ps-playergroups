const { ref, onBeforeUnmount } = Vue


const groups = {
    data() {
        return {
            mainMenuShow: false,
            listShow: false,
            groupShow: false,
            requestShow: false,
            isInGroup: false,
            isGroupLeader: false,
            GroupMembers: [],
            GroupTasks: [],
            CurrentStage: "WAITING",
            GroupID : 0,
            GroupList: [],
            GroupRequests: [],
        };
    },
    setup () {
        return {}
    },
    methods: {
        CreateGroup: async function(event) {
            let result = await $.post(`https://${GetParentResourceName()}/group-create`);
            if (result != false) {
                this.HideMenus()
                this.isInGroup = true
                this.isGroupLeader = true
                this.GroupMembers.push(result)
                this.GroupID = result.groupID
                this.groupShow = true
                this.CurrentStage = "WAITING"
                
                $.post(`https://${GetParentResourceName()}/group-created`, JSON.stringify({
                    GroupID : this.GroupID,
                    status : this.CurrentStage,
                    leader: this.isGroupLeader,
                }));
            } else {
                console.log("Unable to create group");
            }
        },
        AvailableGroups: async function(event) {
            this.HideMenus()
            let temp = []
            let result = await $.post(`https://${GetParentResourceName()}/getActiveGroups`);
            $.each(result, function(index, value) {
                temp.push(value)
            });
            this.GroupList = temp
            this.listShow = true
        },
        RequestJoin: function(id) {
            $.post(`https://${GetParentResourceName()}/request-join`, JSON.stringify({groupID : id }));
        },
        LeaveGroup: function(event) {
            if (this.isInGroup) {
                this.HideMenus()
                this.mainMenuShow = true
                this.isInGroup = false
                this.isGroupLeader = false
                $.post(`https://${GetParentResourceName()}/group-leave`, JSON.stringify({groupID : this.GroupID }));
                this.GroupCleanup()
            }
        },
        MainMenu: function(event) {
            this.HideMenus()
            this.mainMenuShow = true
        },
        ViewGroup: function(event) {
            this.HideMenus()
            this.groupShow = true
        },
        ViewRequests: async function(event) {
            
            this.HideMenus()
            let temp = []
            let result = await $.post(`https://${GetParentResourceName()}/view-requests`, JSON.stringify({groupID : this.GroupID }));
            $.each(result, function(index, value) {
                temp.push(value)
            });
            this.GroupRequests = temp
            this.requestShow = true
        },
        RequestAccept: function(v, id) {
            this.GroupRequests.splice(v, 1);
            $.post(`https://${GetParentResourceName()}/request-accept`, JSON.stringify({player : id, groupID : this.GroupID}));
        },
        RequestDeny: function(v, id) {
            this.GroupRequests.splice(v, 1);
            $.post(`https://${GetParentResourceName()}/request-deny`, JSON.stringify({player : id, groupID : this.GroupID}));
        },
        MemberKick: function(v, id) {
            this.GroupMembers.splice(v, 1);
            $.post(`https://${GetParentResourceName()}/member-kick`, JSON.stringify({player : id, groupID : this.GroupID}));
        },
        HideMenus: function() {
            this.mainMenuShow = false
            this.listShow = false
            this.groupShow = false
            this.requestShow = false
        },
        OpenMenu: function(data) {
            if (!this.isInGroup) {
                this.HideMenus()
                this.mainMenuShow = true
            } else {
                this.HideMenus()
                this.groupShow = true
            }
            $(".groups-container").fadeIn(150);
        },
        JoinGroup: function(data) {
            this.HideMenus()
            this.isInGroup = true
            this.groupShow = true
            this.GroupID = data.groupID
        },
        UpdateGroup: function(data, type) {
            if (type === "leave") {

            } else if (type === "setStage") {
                this.CurrentStage = data.stage
                $.post(`https://${GetParentResourceName()}/update-status`, JSON.stringify({status : this.CurrentStage }));
            } else if (type === "groupDestroy") {
                this.HideMenus()
                this.isInGroup = false
                this.isGroupLeader = false 
                this.GroupCleanup()
            } else if (type === "update") {
                this.GroupMembers = []
                let temp = []
                $.each(data, function(index, value) {
                    temp.push(value)
                });
                this.GroupMembers = temp
            }
        },
        MakeLeader: function() {
            this.isGroupLeader = true 
        },
        GroupCleanup: function() {
            this.GroupMembers = []
            this.GroupTasks = []
            this.CurrentStage = "None"
            this.GroupID = 0
            $.post(`https://${GetParentResourceName()}/group-cleanup`);
        },
    },
    destroyed() {
        window.removeEventListener("message", this.listener);
    },
    mounted() {
        this.listener = window.addEventListener("message", (event) => {
            if (event.data.action === "open") {
                this.OpenMenu(event.data);
            } else if (event.data.action === "update") {
                this.UpdateGroup(event.data.data, event.data.type);
            } else if (event.data.action == "join") {
                this.JoinGroup(event.data)
            } else if (event.data.action == "makeLeader") {
                this.MakeLeader()
            }
        });
    },
}

const app = Vue.createApp(groups);
app.use(Quasar);
app.mount(".groups-container");

document.onkeyup = function (data) {
    if (data.key == 'Escape') {
        closeMenu()
    } 
};
  
function closeMenu() {
    $(".groups-container").fadeOut(150);
    $.post(`https://${GetParentResourceName()}/close`);
}
