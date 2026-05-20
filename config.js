<script>
    const params = new URLSearchParams(window.location.search);
    const botType = params.get('bot');

    // Central Database for your bots
    const botDatabase = {
        'sa': {
            title: "Small Account Setup",
            pass: "IMCBOTSA_9922",
            file: "files/IMCBOT_SA_V9.mq5"
        },
        'master': {
            title: "Master Bot Setup",
            pass: "MASTER_INFINITY_88", // Example password
            file: "files/IMCBOT_MASTER.mq5"
        },
        'king': {
            title: "King Bot Setup",
            pass: "KING_RULE_77",
            file: "files/IMCBOT_KING.mq5"
        },
        'asura': {
            title: "Asura Bot Setup",
            pass: "ASURA_DEMON_66",
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
