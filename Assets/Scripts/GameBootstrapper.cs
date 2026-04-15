using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public sealed class GameBootstrapper : MonoBehaviour
{
    public int enemyCount = 4;

    Material playerMaterial;
    Material enemyMaterial;
    Material turretMaterial;
    Material groundMaterial;
    Material wallMaterial;
    Material projectileMaterial;
    Projectile projectilePrefab;
    Font uiFont;
    GameManager gameManager;

    void Awake()
    {
        uiFont = Resources.GetBuiltinResource<Font>("Arial.ttf");
        CreateMaterials();
        projectilePrefab = CreateProjectilePrefab();
        CreateLighting();
        CreateMap();

        GameObject player = CreateTank("Player Tank", new Vector3(0f, 0.6f, -8f), true);
        CreateCamera(player.transform);
        CreateUi(player);
        CreateEnemies(player.transform);
    }

    void CreateMaterials()
    {
        playerMaterial = CreateMaterial("Player Green", new Color(0.12f, 0.58f, 0.24f));
        enemyMaterial = CreateMaterial("Enemy Red", new Color(0.72f, 0.16f, 0.13f));
        turretMaterial = CreateMaterial("Gunmetal", new Color(0.16f, 0.18f, 0.2f));
        groundMaterial = CreateMaterial("Training Ground", new Color(0.27f, 0.42f, 0.31f));
        wallMaterial = CreateMaterial("Concrete Wall", new Color(0.52f, 0.55f, 0.58f));
        projectileMaterial = CreateMaterial("Shell Yellow", new Color(1f, 0.72f, 0.12f));
    }

    Material CreateMaterial(string materialName, Color color)
    {
        Material material = new Material(Shader.Find("Standard"));
        material.name = materialName;
        material.color = color;
        return material;
    }

    Projectile CreateProjectilePrefab()
    {
        GameObject shell = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        shell.name = "ProjectilePrototype";
        shell.transform.localScale = Vector3.one * 0.32f;
        shell.GetComponent<Renderer>().material = projectileMaterial;

        Rigidbody rigidbody = shell.AddComponent<Rigidbody>();
        rigidbody.useGravity = false;
        rigidbody.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;

        Projectile projectile = shell.AddComponent<Projectile>();
        projectile.damage = 25f;
        projectile.speed = 26f;
        projectile.lifeTime = 4f;
        shell.SetActive(false);
        return projectile;
    }

    void CreateLighting()
    {
        RenderSettings.ambientLight = new Color(0.45f, 0.48f, 0.52f);

        GameObject lightObject = new GameObject("Sun");
        Light light = lightObject.AddComponent<Light>();
        light.type = LightType.Directional;
        light.intensity = 1.15f;
        light.transform.rotation = Quaternion.Euler(50f, -35f, 0f);
    }

    void CreateMap()
    {
        GameObject ground = GameObject.CreatePrimitive(PrimitiveType.Cube);
        ground.name = "Arena Floor";
        ground.transform.position = new Vector3(0f, -0.15f, 0f);
        ground.transform.localScale = new Vector3(34f, 0.3f, 34f);
        ground.GetComponent<Renderer>().material = groundMaterial;

        CreateWall("North Wall", new Vector3(0f, 1.25f, 17f), new Vector3(36f, 2.5f, 1f));
        CreateWall("South Wall", new Vector3(0f, 1.25f, -17f), new Vector3(36f, 2.5f, 1f));
        CreateWall("East Wall", new Vector3(17f, 1.25f, 0f), new Vector3(1f, 2.5f, 36f));
        CreateWall("West Wall", new Vector3(-17f, 1.25f, 0f), new Vector3(1f, 2.5f, 36f));

        CreateWall("Center Block A", new Vector3(-5f, 0.8f, 1f), new Vector3(3f, 1.6f, 5f));
        CreateWall("Center Block B", new Vector3(6f, 0.8f, -2f), new Vector3(4f, 1.6f, 3f));
        CreateWall("Cover North", new Vector3(0f, 0.8f, 9f), new Vector3(7f, 1.6f, 1.2f));
        CreateWall("Cover South", new Vector3(0f, 0.8f, -12f), new Vector3(7f, 1.6f, 1.2f));
        CreateWall("Side Cover Left", new Vector3(-11f, 0.8f, -4f), new Vector3(1.2f, 1.6f, 6f));
        CreateWall("Side Cover Right", new Vector3(12f, 0.8f, 5f), new Vector3(1.2f, 1.6f, 6f));
    }

    void CreateWall(string wallName, Vector3 position, Vector3 scale)
    {
        GameObject wall = GameObject.CreatePrimitive(PrimitiveType.Cube);
        wall.name = wallName;
        wall.transform.position = position;
        wall.transform.localScale = scale;
        wall.GetComponent<Renderer>().material = wallMaterial;
    }

    GameObject CreateTank(string tankName, Vector3 position, bool isPlayer)
    {
        GameObject root = new GameObject(tankName);
        root.transform.position = position;
        root.transform.rotation = Quaternion.Euler(0f, isPlayer ? 0f : 180f, 0f);

        Rigidbody rigidbody = root.AddComponent<Rigidbody>();
        rigidbody.mass = 12f;
        rigidbody.drag = 1.5f;
        rigidbody.angularDrag = 4f;
        rigidbody.interpolation = RigidbodyInterpolation.Interpolate;

        TankHealth health = root.AddComponent<TankHealth>();
        health.maxHealth = isPlayer ? 130f : 85f;
        health.currentHealth = health.maxHealth;

        GameObject body = GameObject.CreatePrimitive(PrimitiveType.Cube);
        body.name = "Body";
        body.transform.SetParent(root.transform, false);
        body.transform.localPosition = new Vector3(0f, 0f, 0f);
        body.transform.localScale = new Vector3(1.8f, 0.7f, 2.3f);
        body.GetComponent<Renderer>().material = isPlayer ? playerMaterial : enemyMaterial;

        GameObject leftTrack = GameObject.CreatePrimitive(PrimitiveType.Cube);
        leftTrack.name = "Left Track";
        leftTrack.transform.SetParent(root.transform, false);
        leftTrack.transform.localPosition = new Vector3(-1.05f, -0.05f, 0f);
        leftTrack.transform.localScale = new Vector3(0.35f, 0.5f, 2.55f);
        leftTrack.GetComponent<Renderer>().material = turretMaterial;

        GameObject rightTrack = GameObject.CreatePrimitive(PrimitiveType.Cube);
        rightTrack.name = "Right Track";
        rightTrack.transform.SetParent(root.transform, false);
        rightTrack.transform.localPosition = new Vector3(1.05f, -0.05f, 0f);
        rightTrack.transform.localScale = new Vector3(0.35f, 0.5f, 2.55f);
        rightTrack.GetComponent<Renderer>().material = turretMaterial;

        GameObject turret = new GameObject("Turret Pivot");
        turret.transform.SetParent(root.transform, false);
        turret.transform.localPosition = new Vector3(0f, 0.55f, 0f);

        GameObject turretVisual = GameObject.CreatePrimitive(PrimitiveType.Cube);
        turretVisual.name = "Turret";
        turretVisual.transform.SetParent(turret.transform, false);
        turretVisual.transform.localScale = new Vector3(1.1f, 0.45f, 1.05f);
        turretVisual.GetComponent<Renderer>().material = isPlayer ? playerMaterial : enemyMaterial;

        GameObject barrel = GameObject.CreatePrimitive(PrimitiveType.Cube);
        barrel.name = "Barrel";
        barrel.transform.SetParent(turret.transform, false);
        barrel.transform.localPosition = new Vector3(0f, 0f, 0.95f);
        barrel.transform.localScale = new Vector3(0.25f, 0.25f, 1.55f);
        barrel.GetComponent<Renderer>().material = turretMaterial;

        GameObject firePoint = new GameObject("Fire Point");
        firePoint.transform.SetParent(turret.transform, false);
        firePoint.transform.localPosition = new Vector3(0f, 0f, 1.85f);

        CreateWorldHealthBar(root.transform, health, isPlayer);

        if (isPlayer)
        {
            TankController controller = root.AddComponent<TankController>();
            controller.turret = turret.transform;
            controller.firePoint = firePoint.transform;
            controller.projectilePrefab = projectilePrefab;
            controller.moveSpeed = 8f;
            controller.turnSpeed = 115f;

            SkillSystem skills = root.AddComponent<SkillSystem>();
            skills.controller = controller;
            skills.health = health;
        }

        return root;
    }

    void CreateEnemies(Transform player)
    {
        Vector3[] spawnPoints =
        {
            new Vector3(-11f, 0.6f, 10f),
            new Vector3(11f, 0.6f, 10f),
            new Vector3(-12f, 0.6f, -8f),
            new Vector3(12f, 0.6f, -10f)
        };

        for (int i = 0; i < Mathf.Min(enemyCount, spawnPoints.Length); i++)
        {
            GameObject enemy = CreateTank("Enemy Tank " + (i + 1), spawnPoints[i], false);
            TankAI ai = enemy.AddComponent<TankAI>();
            ai.player = player;
            ai.turret = enemy.transform.Find("Turret Pivot");
            ai.firePoint = ai.turret.Find("Fire Point");
            ai.projectilePrefab = projectilePrefab;
            ai.patrolPoints = CreatePatrolPoints(spawnPoints[i], i);

            TankHealth health = enemy.GetComponent<TankHealth>();
            if (gameManager != null)
            {
                gameManager.RegisterEnemy(health);
            }
        }
    }

    Vector3[] CreatePatrolPoints(Vector3 center, int index)
    {
        float offset = 3.5f + index;
        return new[]
        {
            center + new Vector3(-offset, 0f, 0f),
            center + new Vector3(0f, 0f, offset),
            center + new Vector3(offset, 0f, 0f),
            center + new Vector3(0f, 0f, -offset)
        };
    }

    void CreateCamera(Transform target)
    {
        GameObject cameraObject = new GameObject("Main Camera");
        cameraObject.tag = "MainCamera";
        Camera camera = cameraObject.AddComponent<Camera>();
        camera.fieldOfView = 55f;
        camera.nearClipPlane = 0.1f;
        camera.farClipPlane = 150f;
        cameraObject.AddComponent<AudioListener>();

        CameraFollow follow = cameraObject.AddComponent<CameraFollow>();
        follow.target = target;
        cameraObject.transform.position = target.position + follow.perspectiveOffset;
        cameraObject.transform.rotation = Quaternion.LookRotation(target.position - cameraObject.transform.position + Vector3.up * 1.5f, Vector3.up);
    }

    void CreateUi(GameObject player)
    {
        if (FindObjectOfType<EventSystem>() == null)
        {
            GameObject eventSystem = new GameObject("EventSystem");
            eventSystem.AddComponent<EventSystem>();
            eventSystem.AddComponent<StandaloneInputModule>();
        }

        GameObject canvasObject = new GameObject("HUD Canvas");
        Canvas canvas = canvasObject.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        CanvasScaler scaler = canvasObject.AddComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(1920f, 1080f);
        canvasObject.AddComponent<GraphicRaycaster>();

        Text status = CreateText(canvas.transform, "Status Text", "Destroy all enemy tanks", new Vector2(0.5f, 1f), new Vector2(0f, -36f), 30, TextAnchor.UpperCenter);
        Text objective = CreateText(canvas.transform, "Objective Text", "Enemies: 0", new Vector2(1f, 1f), new Vector2(-28f, -28f), 26, TextAnchor.UpperRight);
        CreateText(canvas.transform, "Control Hint", "WASD move | Mouse aim/fire | Q speed | E shield | R power", new Vector2(0.5f, 0f), new Vector2(0f, 28f), 22, TextAnchor.LowerCenter);

        Slider playerHealth = CreateHudSlider(canvas.transform, "Player Health", new Vector2(0f, 1f), new Vector2(28f, -34f), new Vector2(360f, 26f));
        HealthBar hudHealth = playerHealth.gameObject.AddComponent<HealthBar>();
        hudHealth.target = player.GetComponent<TankHealth>();
        hudHealth.slider = playerHealth;
        hudHealth.fill = playerHealth.fillRect.GetComponent<Image>();
        hudHealth.faceCamera = false;

        SkillHUD skillHud = canvasObject.AddComponent<SkillHUD>();
        skillHud.skillSystem = player.GetComponent<SkillSystem>();
        CreateSkillSlot(canvas.transform, "Speed Slot", new Vector2(0f, 0f), new Vector2(28f, 30f), "Q Speed", out skillHud.speedFill, out skillHud.speedText);
        CreateSkillSlot(canvas.transform, "Shield Slot", new Vector2(0f, 0f), new Vector2(158f, 30f), "E Shield", out skillHud.shieldFill, out skillHud.shieldText);
        CreateSkillSlot(canvas.transform, "Power Slot", new Vector2(0f, 0f), new Vector2(288f, 30f), "R Power", out skillHud.powerFill, out skillHud.powerText);

        GameObject managerObject = new GameObject("Game Manager");
        gameManager = managerObject.AddComponent<GameManager>();
        gameManager.player = player.GetComponent<TankHealth>();
        gameManager.statusText = status;
        gameManager.objectiveText = objective;
    }

    Text CreateText(Transform parent, string name, string value, Vector2 anchor, Vector2 anchoredPosition, int size, TextAnchor alignment)
    {
        GameObject textObject = new GameObject(name);
        textObject.transform.SetParent(parent, false);
        RectTransform rect = textObject.AddComponent<RectTransform>();
        rect.anchorMin = anchor;
        rect.anchorMax = anchor;
        rect.pivot = anchor;
        rect.anchoredPosition = anchoredPosition;
        rect.sizeDelta = new Vector2(760f, 80f);

        Text text = textObject.AddComponent<Text>();
        text.font = uiFont;
        text.fontSize = size;
        text.alignment = alignment;
        text.color = Color.white;
        text.text = value;
        return text;
    }

    Slider CreateHudSlider(Transform parent, string name, Vector2 anchor, Vector2 position, Vector2 size)
    {
        GameObject sliderObject = new GameObject(name);
        sliderObject.transform.SetParent(parent, false);
        RectTransform rect = sliderObject.AddComponent<RectTransform>();
        rect.anchorMin = anchor;
        rect.anchorMax = anchor;
        rect.pivot = anchor;
        rect.anchoredPosition = position;
        rect.sizeDelta = size;
        return BuildSlider(sliderObject.transform);
    }

    void CreateSkillSlot(Transform parent, string name, Vector2 anchor, Vector2 position, string label, out Image cooldownFill, out Text text)
    {
        GameObject slot = new GameObject(name);
        slot.transform.SetParent(parent, false);
        RectTransform rect = slot.AddComponent<RectTransform>();
        rect.anchorMin = anchor;
        rect.anchorMax = anchor;
        rect.pivot = anchor;
        rect.anchoredPosition = position;
        rect.sizeDelta = new Vector2(112f, 68f);

        Image background = slot.AddComponent<Image>();
        background.color = new Color(0.08f, 0.09f, 0.1f, 0.78f);

        GameObject fillObject = new GameObject("Cooldown Fill");
        fillObject.transform.SetParent(slot.transform, false);
        RectTransform fillRect = fillObject.AddComponent<RectTransform>();
        fillRect.anchorMin = Vector2.zero;
        fillRect.anchorMax = Vector2.one;
        fillRect.offsetMin = Vector2.zero;
        fillRect.offsetMax = Vector2.zero;
        cooldownFill = fillObject.AddComponent<Image>();
        cooldownFill.type = Image.Type.Filled;
        cooldownFill.fillMethod = Image.FillMethod.Radial360;
        cooldownFill.color = new Color(0f, 0f, 0f, 0.55f);

        GameObject textObject = new GameObject("Label");
        textObject.transform.SetParent(slot.transform, false);
        RectTransform textRect = textObject.AddComponent<RectTransform>();
        textRect.anchorMin = Vector2.zero;
        textRect.anchorMax = Vector2.one;
        textRect.offsetMin = Vector2.zero;
        textRect.offsetMax = Vector2.zero;
        text = textObject.AddComponent<Text>();
        text.font = uiFont;
        text.fontSize = 16;
        text.alignment = TextAnchor.MiddleCenter;
        text.color = Color.white;
        text.text = label + "\nReady";
    }

    void CreateWorldHealthBar(Transform tank, TankHealth health, bool isPlayer)
    {
        GameObject canvasObject = new GameObject("World Health Bar");
        canvasObject.transform.SetParent(tank, false);
        canvasObject.transform.localPosition = new Vector3(0f, 1.65f, 0f);
        canvasObject.transform.localScale = Vector3.one * 0.018f;

        Canvas canvas = canvasObject.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.WorldSpace;
        canvasObject.AddComponent<GraphicRaycaster>();

        RectTransform canvasRect = canvasObject.GetComponent<RectTransform>();
        canvasRect.sizeDelta = new Vector2(140f, 18f);

        Slider slider = BuildSlider(canvasObject.transform);
        HealthBar bar = canvasObject.AddComponent<HealthBar>();
        bar.target = health;
        bar.slider = slider;
        bar.fill = slider.fillRect.GetComponent<Image>();
        bar.healthyColor = isPlayer ? new Color(0.2f, 0.9f, 0.25f) : new Color(0.95f, 0.34f, 0.2f);
    }

    Slider BuildSlider(Transform parent)
    {
        GameObject backgroundObject = new GameObject("Background");
        backgroundObject.transform.SetParent(parent, false);
        RectTransform backgroundRect = backgroundObject.AddComponent<RectTransform>();
        backgroundRect.anchorMin = Vector2.zero;
        backgroundRect.anchorMax = Vector2.one;
        backgroundRect.offsetMin = Vector2.zero;
        backgroundRect.offsetMax = Vector2.zero;
        Image background = backgroundObject.AddComponent<Image>();
        background.color = new Color(0.08f, 0.08f, 0.08f, 0.8f);

        GameObject fillArea = new GameObject("Fill Area");
        fillArea.transform.SetParent(parent, false);
        RectTransform fillAreaRect = fillArea.AddComponent<RectTransform>();
        fillAreaRect.anchorMin = Vector2.zero;
        fillAreaRect.anchorMax = Vector2.one;
        fillAreaRect.offsetMin = new Vector2(2f, 2f);
        fillAreaRect.offsetMax = new Vector2(-2f, -2f);

        GameObject fillObject = new GameObject("Fill");
        fillObject.transform.SetParent(fillArea.transform, false);
        RectTransform fillRect = fillObject.AddComponent<RectTransform>();
        fillRect.anchorMin = Vector2.zero;
        fillRect.anchorMax = Vector2.one;
        fillRect.offsetMin = Vector2.zero;
        fillRect.offsetMax = Vector2.zero;
        Image fillImage = fillObject.AddComponent<Image>();
        fillImage.color = new Color(0.2f, 0.85f, 0.25f);

        Slider slider = parent.gameObject.AddComponent<Slider>();
        slider.transition = Selectable.Transition.None;
        slider.minValue = 0f;
        slider.maxValue = 1f;
        slider.value = 1f;
        slider.fillRect = fillRect;
        slider.targetGraphic = fillImage;
        slider.interactable = false;
        return slider;
    }
}
