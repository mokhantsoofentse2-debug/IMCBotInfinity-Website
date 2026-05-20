<script>
    const params = new URLSearchParams(window.location.search);
    const botType = params.get('bot');

    // Central Database for your bots
    const botDatabase = {
        'sa': {
            title: "Small Account Setup",
            pass: "IMCBOTSA_9922",
            file: "files/IMCBOT_SA.mq5"
        },
        'master': {
            title: "Master Bot Setup",
            pass: "IMCBOTMaster_101033", 
            file: "files/IMCBOT_Master.mq5"
        },
        'king': {
            title: "King Bot Setup",
            pass: "IMCBOTKing_10111",
            file: "files/IMCBOT_KING.mq5"
        },
        'asura': {
            title: "Asura Bot Setup",
            pass: "IMCBOTAsura_10112",
            file: "files/IMCBOT_ASURA.mq5"
        }
    };

    // Initialize Page
    const currentBot = botDatabase[botType];
    if (currentBot) {
        document.getElementById('botTitle').innerText = "IMCBOT " + currentBot.title;
    } else {
        document.getElementById('botTitle').innerText = "Invalid Bot Selected";
    }

    function verifyBot() {
        const inputPass = document.getElementById('pass').value;
        const area = document.getElementById('downloadArea');
        const link = document.getElementById('botLink');

        if (currentBot && inputPass === currentBot.pass) {
            area.style.display = 'block';
            link.href = currentBot.file;
        } else {
            alert("Incorrect password or unauthorized access attempt.");
        }
    }
</script>
